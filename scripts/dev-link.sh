#!/usr/bin/env bash
# Link this repo's plugins into ~/.claude/skills/ so edits load live.
#
# Usage: scripts/dev-link.sh [--unlink]
#
# Claude Code auto-loads any plugin directory under ~/.claude/skills/ as
# <name>@skills-dir on the next session start. Symlinking means every edit in
# this repo is live immediately — no install, no version bump, no push.
#
# Use this on the machine where you author skills. On other machines, install
# from the marketplace instead (see README). Doing both on one machine loads
# the same skills twice.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skills_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
mkdir -p "$skills_dir"

for plugin_dir in "$repo_root"/plugins/*/; do
  [[ -f "$plugin_dir/.claude-plugin/plugin.json" ]] || continue
  name="$(basename "$plugin_dir")"
  target="$skills_dir/$name"

  if [[ "${1:-}" == "--unlink" ]]; then
    if [[ -L "$target" ]]; then
      rm "$target"
      echo "unlinked $target"
    else
      echo "skip $target (not a symlink)"
    fi
    continue
  fi

  if [[ -e "$target" && ! -L "$target" ]]; then
    echo "error: $target exists and is not a symlink — remove it first" >&2
    exit 1
  fi

  ln -sfn "${plugin_dir%/}" "$target"
  echo "linked $target -> ${plugin_dir%/}"
done

echo "restart Claude Code to pick up changes to the plugin manifest"
