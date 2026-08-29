# Working in this repo

This repo is a Claude Code plugin marketplace holding Ricardo's personal skills. It is
consumed by Claude Code, not built or run — there is no app here.

## Conventions

- One skill per directory: `plugins/<plugin>/skills/<skill-name>/SKILL.md`, kebab-case.
- Scaffold with `scripts/new-skill.sh <name> "<description>"` rather than hand-creating dirs.
- `SKILL.md` frontmatter: `name` must equal the directory name; `description` states *when*
  to use the skill in the user's own words. Add `argument-hint` / `allowed-tools` only for
  slash-command skills.
- Keep `SKILL.md` bodies short and imperative (~200 lines max). Long material goes in
  `references/`, `scripts/`, or `assets/` beside it, referenced from the body.
- Every plugin listed in `.claude-plugin/marketplace.json` needs a matching
  `plugins/<name>/.claude-plugin/plugin.json`, and the `version` fields must agree if both
  declare one.
- Run `scripts/validate.sh` after any change to a manifest or a skill.
- Bump the plugin `version` when publishing a change other machines should pick up.
