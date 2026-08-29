#!/usr/bin/env bash
# Scaffold a new skill inside this repo.
#
# Usage: scripts/new-skill.sh <skill-name> [one-line description]
#
# Creates plugins/<plugin>/skills/<skill-name>/SKILL.md from a template.
# Override the target plugin with PLUGIN=<name> (default: zambon).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin="${PLUGIN:-zambon}"

name="${1:-}"
shift || true
description="${*:-}"

if [[ -z "$name" ]]; then
  echo "usage: scripts/new-skill.sh <skill-name> [description]" >&2
  exit 2
fi

if [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "error: skill name must be lowercase kebab-case (got '$name')" >&2
  exit 2
fi

plugin_dir="$repo_root/plugins/$plugin"
if [[ ! -d "$plugin_dir" ]]; then
  echo "error: no plugin at plugins/$plugin" >&2
  exit 2
fi

skill_dir="$plugin_dir/skills/$name"
if [[ -e "$skill_dir/SKILL.md" ]]; then
  echo "error: $skill_dir/SKILL.md already exists" >&2
  exit 1
fi

mkdir -p "$skill_dir"
cat > "$skill_dir/SKILL.md" <<EOF
---
name: $name
description: ${description:-TODO — say what this does AND when Claude should reach for it, in trigger terms (\"Use when the user ...\"). This text is the only thing Claude sees before loading the skill.}
---

# ${name//-/ }

## When to use

- TODO: concrete situations that should trigger this skill.

## Steps

1. TODO
2. TODO

## Notes

- TODO: gotchas, conventions, links to reference files in this directory.
EOF

echo "created $skill_dir/SKILL.md"
echo "next: edit it, then run scripts/validate.sh"
