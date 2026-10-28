"""Benchmark /kix:preflight end to end: an old plugin revision against a new one.

    uv run --with claude-agent-sdk python scripts/bench-preflight.py \
        [--old b9db0ab] [--new HEAD] [--repeats 1] [--out DIR] [--model M]

Builds one fixture repo — a no-local clone of this repo with a local bare
origin, .beads replaced by a fresh `bd init` (no Dolt remote), a bead with
acceptance criteria, a branch named after it holding a bug and a plan with
two unchecked boxes, and origin/main one commit ahead — then, per repeat,
runs old and new in parallel, each on its own copy of the fixture:

  first   /kix:preflight on the fixture (rebase, checks, fixes, verdict)
  rerun   /kix:preflight again in the same session (the ship gate's case)

Every AskUserQuestion is answered with its first (Recommended) option. A
PreToolUse hook denies gh, github.com, dolthub and anything naming this
checkout, so a run can't reach the real repo or the network. Each message is
logged to <out>/runs/<run>/messages.jsonl; the summary — duration, turns,
tool calls, cost, tokens per phase — goes to <out>/summary.json and stdout.

Costs real API usage: roughly $1-3 per run and phase.
"""

import argparse
import asyncio
import dataclasses
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from claude_agent_sdk import (
    AssistantMessage,
    ClaudeAgentOptions,
    ClaudeSDKClient,
    HookMatcher,
    PermissionResultAllow,
    ResultMessage,
    ToolUseBlock,
)

REPO = Path(
    subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
)
# The main checkout too, when this runs from a worktree.
MAIN = Path(
    subprocess.check_output(
        ["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], text=True
    ).strip()
).parent
FORBIDDEN = re.compile(
    r"\bgh\b|github\.com|dolthub|" + re.escape(str(REPO)) + "|" + re.escape(str(MAIN))
)


def sh(cmd, cwd, **kw):
    return subprocess.run(
        cmd, cwd=cwd, shell=True, check=True, text=True, capture_output=True, **kw
    ).stdout.strip()


def git_env():
    env = dict(os.environ)
    for k in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR"):
        env.pop(k, None)
    env.update(
        GIT_AUTHOR_NAME="bench",
        GIT_AUTHOR_EMAIL="bench@example.invalid",
        GIT_COMMITTER_NAME="bench",
        GIT_COMMITTER_EMAIL="bench@example.invalid",
    )
    return env


def extract_plugin(rev, dest):
    dest.mkdir(parents=True)
    subprocess.run(
        f"git archive {rev} claude-code | tar -x -C {dest}",
        cwd=REPO,
        shell=True,
        check=True,
    )
    return dest / "claude-code"


BUGGY = """#!/usr/bin/env bash
# count-skills — how many skills the plugin ships.
set -euo pipefail
dir=${1:-claude-code/skills}
n=0
for d in "$dir"/*; do
  n=$((n + 1))
done
# Every skill folder holds a SKILL.md.
echo "$((n + 1)) skills"
"""

PLAN = """# count-skills plan

- [x] Write scripts/count-skills.sh
- [x] Print the count
- [ ] Add a test under scripts/
- [ ] Mention it in README.md
"""


def build_fixture(root):
    env = git_env()
    origin, repo, seed = root / "origin.git", root / "repo", root / "seed"
    sh(f"git clone -q --bare --no-local --branch main {REPO} {origin}", root, env=env)
    sh(f"git clone -q {origin} {repo}", root, env=env)
    sh("rm -rf .beads && bd init -q --non-interactive -p fx", repo, env=env)
    # The repo's own suites take minutes; `make test` runs only what the
    # branch adds.
    sh("git rm -q $(ls scripts/test-*.sh | grep -v test-git-env.sh)", repo, env=env)
    # bd init commits on its own; commit whatever it left.
    sh("git add -A && { git diff --cached --quiet || git commit -q -m 'fixture: fresh beads'; }"
       " && git push -q origin HEAD:main", repo, env=env)
    bead = sh(
        "bd create --silent --type=feature --priority=2"
        " --title='Add scripts/count-skills.sh'"
        " --description='A script that prints how many skills the plugin ships.'"
        " --acceptance='1. scripts/count-skills.sh prints the number of skill folders.\n"
        "2. A test covers it.'",
        repo,
        env=env,
    )
    sh(f"git switch -q -c {bead}-count-skills", repo, env=env)
    (repo / "scripts/count-skills.sh").write_text(BUGGY)
    (repo / "scripts/count-skills.sh").chmod(0o755)
    plan = repo / "docs/kix" / bead / "plan.md"
    plan.parent.mkdir(parents=True)
    plan.write_text(PLAN)
    sh(f"git add -A && git commit -q -m 'feat({bead}): count skills'", repo, env=env)
    sh(f"git push -q -u origin HEAD", repo, env=env)
    # origin/main one commit ahead of the branch's base.
    sh(f"git clone -q {origin} {seed}", root, env=env)
    (seed / "docs/upstream.md").write_text("# Upstream\n\nA change on main.\n")
    sh("git add -A && git commit -q -m 'docs: upstream change' && git push -q origin HEAD:main", seed, env=env)
    shutil.rmtree(seed)
    return bead


def copy_fixture(fixture, dest):
    shutil.copytree(fixture, dest, symlinks=True)
    sh(f"git remote set-url origin {dest / 'origin.git'}", dest / "repo", env=git_env())


async def answer_questions(tool_name, tool_input, context):
    if tool_name == "AskUserQuestion":
        answers = {
            q["question"]: q["options"][0]["label"] for q in tool_input.get("questions", [])
        }
        return PermissionResultAllow(updated_input={**tool_input, "answers": answers})
    return PermissionResultAllow()


async def guard(input_data, tool_use_id, context):
    text = json.dumps(input_data.get("tool_input", {}))
    if FORBIDDEN.search(text):
        return {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": "benchmark sandbox: no GitHub, DoltHub or real repo",
            }
        }
    return {}


def to_json(msg):
    try:
        d = dataclasses.asdict(msg)
    except TypeError:
        d = {"repr": repr(msg)}
    d["_type"] = type(msg).__name__
    d["_t"] = time.time()
    return json.dumps(d, default=str)


async def phase(client, prompt, log):
    await client.query(prompt)
    tools = 0
    async for msg in client.receive_response():
        log.write(to_json(msg) + "\n")
        log.flush()
        if isinstance(msg, AssistantMessage):
            tools += sum(isinstance(b, ToolUseBlock) for b in msg.content)
        if isinstance(msg, ResultMessage):
            u = msg.usage or {}
            return {
                "duration_s": round(msg.duration_ms / 1000, 1),
                "turns": msg.num_turns,
                "tool_calls": tools,
                "cost_usd": round(msg.total_cost_usd or 0, 2),
                "input_tokens": u.get("input_tokens", 0)
                + u.get("cache_read_input_tokens", 0)
                + u.get("cache_creation_input_tokens", 0),
                "output_tokens": u.get("output_tokens", 0),
                "is_error": msg.is_error,
            }
    return {"error": "no result"}


def run_path(plugin):
    """PATH with the plugin's bin first and no copy of this repo's bin."""
    keep = [
        d
        for d in os.environ.get("PATH", "").split(os.pathsep)
        if not d.startswith((str(REPO), str(MAIN)))
    ]
    return os.pathsep.join([str(plugin / "bin")] + keep)


async def run(name, plugin, workdir, model):
    os.environ.pop("CLAUDE_CODE_SESSION_ID", None)
    options = ClaudeAgentOptions(
        cwd=str(workdir / "repo"),
        plugins=[{"type": "local", "path": str(plugin)}],
        setting_sources=["user"],
        settings=json.dumps({"enabledPlugins": {"kix@kix-agents": False}}),
        permission_mode="default",
        can_use_tool=answer_questions,
        hooks={"PreToolUse": [HookMatcher(matcher=None, hooks=[guard])]},
        env={"KIX_FETCH_TTL": "5", "PATH": run_path(plugin)},
        model=model,
    )
    result = {"run": name}
    with open(workdir / "messages.jsonl", "w") as log:
        async with ClaudeSDKClient(options) as client:
            result["first"] = await phase(client, "/kix:preflight", log)
            result["rerun"] = await phase(client, "/kix:preflight", log)
    print(json.dumps(result), flush=True)
    return result


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--old", default="b9db0ab")
    ap.add_argument("--new", default="HEAD")
    ap.add_argument("--repeats", type=int, default=1)
    ap.add_argument("--out", type=Path)
    ap.add_argument("--model")
    a = ap.parse_args()
    out = a.out or Path(tempfile.mkdtemp(prefix="bench-preflight-"))
    out.mkdir(parents=True, exist_ok=True)
    print(f"out: {out}", flush=True)
    plugins = {
        "old": extract_plugin(a.old, out / "plugins/old"),
        "new": extract_plugin(a.new, out / "plugins/new"),
    }
    fixture = out / "fixture"
    fixture.mkdir()
    bead = build_fixture(fixture)
    print(f"fixture: bead {bead}", flush=True)
    results = []
    for r in range(1, a.repeats + 1):
        jobs = []
        for name, plugin in plugins.items():
            wd = out / "runs" / f"{name}-r{r}"
            copy_fixture(fixture, wd)
            jobs.append(run(f"{name}-r{r}", plugin, wd, a.model))
        results += await asyncio.gather(*jobs)
    (out / "summary.json").write_text(json.dumps(results, indent=2))
    print(f"summary: {out / 'summary.json'}")


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
