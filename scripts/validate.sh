#!/usr/bin/env bash
# Validate every plugin and skill in this repo.
#
# Usage: scripts/validate.sh
#
# Runs `claude plugin validate --strict` on the marketplace and each plugin,
# then checks SKILL.md frontmatter (name matches directory, description present).
set -uo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
status=0

if command -v claude >/dev/null 2>&1; then
  echo "== claude plugin validate --strict ."
  claude plugin validate --strict . || status=1
  for plugin_dir in plugins/*/; do
    [[ -f "$plugin_dir/.claude-plugin/plugin.json" ]] || continue
    echo "== claude plugin validate --strict $plugin_dir"
    claude plugin validate --strict "$plugin_dir" || status=1
  done
else
  echo "note: 'claude' CLI not on PATH, skipping manifest validation"
fi

echo "== SKILL.md frontmatter"
python3 - <<'PY' || status=1
import pathlib, re, sys

ok = True
skills = sorted(pathlib.Path("plugins").glob("*/skills/*/SKILL.md"))
if not skills:
    print("  no skills found")

for path in skills:
    text = path.read_text(encoding="utf-8")
    m = re.match(r"---\n(.*?)\n---\n", text, re.S)
    if not m:
        print(f"  FAIL {path}: missing YAML frontmatter")
        ok = False
        continue

    fields = {}
    for line in m.group(1).splitlines():
        km = re.match(r"([A-Za-z0-9_-]+):\s*(.*)$", line)
        if km:
            fields[km.group(1)] = km.group(2).strip()

    name = fields.get("name", "")
    desc = fields.get("description", "")
    expected = path.parent.name

    problems = []
    if name != expected:
        problems.append(f"name '{name}' does not match directory '{expected}'")
    if not desc:
        problems.append("empty description")
    elif desc.startswith("TODO"):
        problems.append("description is still a TODO placeholder")
    elif len(desc) > 1024:
        problems.append(f"description over 1024 chars ({len(desc)})")

    if problems:
        ok = False
        print(f"  FAIL {path}")
        for problem in problems:
            print(f"       - {problem}")
    else:
        print(f"  ok   {path}")

sys.exit(0 if ok else 1)
PY

if [[ $status -eq 0 ]]; then
  echo "all checks passed"
else
  echo "validation failed" >&2
fi
exit $status
