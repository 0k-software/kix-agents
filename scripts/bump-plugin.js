#!/usr/bin/env node
const fs = require("fs");

const [, , part = "patch", file = "claude-code/.claude-plugin/plugin.json"] =
  process.argv;

const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
const [maj, min, pat] = pkg.version.split(".").map(Number);

let next;
switch (part) {
  case "major":
    next = `${maj + 1}.0.0`;
    break;
  case "minor":
    next = `${maj}.${min + 1}.0`;
    break;
  case "patch":
    next = `${maj}.${min}.${pat + 1}`;
    break;
  default:
    console.error(`unknown PART: ${part} (expected major|minor|patch)`);
    process.exit(1);
}

const prev = pkg.version;
pkg.version = next;
fs.writeFileSync(file, JSON.stringify(pkg, null, 2) + "\n");
console.log(`${file}: ${prev} -> ${next}`);
