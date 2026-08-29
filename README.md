# skills

Ricardo Zambon's personal Claude Code skills, packaged as a plugin marketplace so they can
be installed on any machine with two commands.

## Install (any machine)

```bash
claude plugin marketplace add RicardoZambon/skills
claude plugin install zambon@zambon-skills
```

Or from inside Claude Code: `/plugin marketplace add RicardoZambon/skills` then
`/plugin install zambon@zambon-skills`.

Pull later changes with:

```bash
claude plugin marketplace update zambon-skills
claude plugin update zambon@zambon-skills
```

## Author (the machine holding this repo)

Symlink the plugin into `~/.claude/skills/` once — after that every edit is live, with no
install, version bump, or push in the loop:

```bash
scripts/dev-link.sh          # link (undo with --unlink)
```

Claude Code auto-loads plugin directories under `~/.claude/skills/`, so the skills show up
as `zambon@skills-dir` on the next session start. Don't also install from the marketplace
on this machine — the same skills would load twice.

### Add a skill

```bash
scripts/new-skill.sh my-skill "Use when the user asks to ..."
$EDITOR plugins/zambon/skills/my-skill/SKILL.md
scripts/validate.sh
git add -A && git commit -m "add my-skill" && git push
```

Or just ask Claude: `/new-skill my-skill` — the `new-skill` skill in this repo drives the
same flow and covers what makes a good `description`.

## Layout

```
.claude-plugin/marketplace.json     # marketplace manifest — lists the plugins below
plugins/
  zambon/                           # the plugin (add more dirs for more plugins)
    .claude-plugin/plugin.json      # plugin manifest — name, version, author
    skills/
      new-skill/SKILL.md            # one directory per skill
scripts/
  new-skill.sh                      # scaffold a skill
  dev-link.sh                       # symlink plugins into ~/.claude/skills
  validate.sh                       # validate manifests + skill frontmatter
```

A skill is a directory with a `SKILL.md`. Its frontmatter `description` is the only thing
Claude reads before deciding to load it, so write it in trigger terms — the words you would
actually use when you want it.

Supporting material (`references/`, `scripts/`, `assets/`) goes next to `SKILL.md` and is
loaded only when the skill points to it.

## Adding a second plugin

Create `plugins/<name>/.claude-plugin/plugin.json`, add an entry to
`.claude-plugin/marketplace.json` pointing at `./plugins/<name>`, and re-run
`scripts/validate.sh`. Useful when a group of skills should be installable on its own —
work-only skills, say, versus personal ones.

## Validation

`scripts/validate.sh` runs `claude plugin validate --strict` on the marketplace and every
plugin, then checks that each `SKILL.md` has frontmatter whose `name` matches its directory
and whose `description` is filled in. CI runs the same script on every push.
