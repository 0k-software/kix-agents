#!/bin/bash
set -euo pipefail

cd "$CLAUDE_PROJECT_DIR"
make setup
"$CLAUDE_PROJECT_DIR/.claude/hooks/install-dolt.sh" || true
"$CLAUDE_PROJECT_DIR/.claude/hooks/install-bd.sh" || true
"$CLAUDE_PROJECT_DIR/.claude/hooks/bootstrap-bd.sh" || true
