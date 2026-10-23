---
name: writing-style
description: Write or tighten a longer text that people will read — a PR or MR description, ADR, design doc, ticket, review comment, README section, release notes, status update or commit message — using the plugin's writing rules, worked examples and a checker script. Use whenever you are about to write one of these, even if the user did not ask about style, and whenever the user says "tighten this", "make this readable", "too long", "too dense", "check my writing" or "is this clear".
---

# Writing style

The short rules come from `rules.md` in this skill's folder. This plugin's SessionStart hook loads them into every session, so they are usually already in context. If they are not, read `rules.md` first.

This skill adds what a rule list can't: a process for longer texts, before-and-after examples, and a checker that catches what re-reading misses.

## Steps

1. **Pick the reader and the point.** Decide who reads this and what they must know or do afterwards. Open with that. Everything else supports it or goes.
2. **Use a shape that fits** (below). A familiar shape lets the reader skim.
3. **Draft against the rules.** For a first long text in a session, read `references/examples.md`. Examples show the style better than rules.
4. **Run the checker** on the draft. Save the draft to a scratch file, or pipe it in:

   ```bash
   perl "<this skill's folder>/scripts/check-prose.pl" draft.md
   ```

   It flags `§` citations, file:line locations, bare commit hashes, ticket/ADR/PR/MR references without a link, and sentences over 25 words (`--max-words N` changes that). It skips front matter, code blocks and anything under a References heading.
5. **Fix each hit, or keep it on purpose.** The checker matches patterns. It doesn't understand the text. A long sentence in a table may be fine. A hash the reader needs goes under References.
6. **Re-read once as the reader.** Cut any sentence they would not miss.

## Shapes that work

- **PR or MR description:** what changes and why, in two to four sentences. Then how to check it, then any risks. References at the end.
- **Review comment:** the problem, why it matters, the fix. One problem per comment.
- **Commit message:** the subject says what changed. The body says why.
- **Ticket:** what is wrong or wanted, how to reproduce or accept it, then links.
- **ADR:** the question, the decision, why, and what would make you revisit it.
- **Status update:** where it stands, what is blocked, what you need from the reader.

## References section

When a file path, line number or commit hash is truly needed, list it at the end under a `## References` heading. One line each, with a few words on what it is. The body stays readable, and the details are still there for whoever needs them.
