---
name: new-skill
description: Create a new skill in the personal skills repo (github.com/RicardoZambon/skills) — scaffolds the directory, writes SKILL.md, and validates it. Use when the user says "make this a skill", "add a skill for ...", or /new-skill.
argument-hint: <skill-name> [what it should do]
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

# New skill

Add a skill to the personal skills repo so it is available in every Claude Code session.

## Steps

1. **Locate the repo.** It normally lives at `~/workspace/GitHub/skills` or wherever
   `plugins/*/.claude-plugin/plugin.json` exists. If the current working directory is not
   that repo, ask the user for the path rather than guessing.

2. **Pick a name.** Lowercase kebab-case, verb-or-noun phrase, specific enough to be
   recognizable in a list of skills (`deploy-staging`, not `helper`). Default plugin is
   `zambon`; use `PLUGIN=<name>` for a different one.

3. **Scaffold:**

   ```bash
   scripts/new-skill.sh <skill-name> "<one-line description>"
   ```

4. **Write the skill.** Replace every `TODO` in the generated `SKILL.md`:

   - **`description` is the most important line.** It is the only text Claude sees before
     deciding to load the skill, so it must name the *trigger*, not just the topic:
     "Use when the user asks to ... / mentions ... / is working on ...". Include the words
     the user would actually say.
   - Keep the body short and imperative — instructions for Claude, not prose for a reader.
     Under ~200 lines. Anything long (schemas, examples, checklists, scripts) goes in a
     sibling file the skill points to: `references/*.md`, `scripts/*.sh`, `assets/*`.
   - Add `argument-hint` and `allowed-tools` only for skills meant to be invoked as a
     slash command; omit them for skills Claude should reach for on its own.

5. **Validate:**

   ```bash
   scripts/validate.sh
   ```

6. **Ship it.** Commit and push. The change is live immediately if the repo is dev-linked
   (`scripts/dev-link.sh`); on other machines run `/plugin update zambon@zambon-skills`.
   Bump `version` in `plugins/<plugin>/.claude-plugin/plugin.json` when the change is
   worth flagging to other machines.

## Notes

- Existing skills in `plugins/*/skills/` are the best format reference — read one before
  writing a new one.
- A skill that only ever runs when the user explicitly asks for it is a slash command;
  a skill that should fire on context is a model-invoked skill. Both live in
  `skills/<name>/SKILL.md`; the frontmatter is the only difference.
