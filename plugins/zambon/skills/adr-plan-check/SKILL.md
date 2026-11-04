---
name: adr-plan-check
description: Check an ADR, design doc or implementation plan the user wrote against the current ADR register before they push it or ask for review. Finds every ADR it cites, reports what changed in each since the doc's "checked against" stamp, catches quotes that no longer match, wrong statuses, positional citations that will go stale, ADRs added since, and leftover placeholders; then verifies each claim about an ADR and that every departure from one is marked, tabled and gated. Use when the user says "check my ADR", "check my plan", "is my plan okay", "are my ADR citations current", "did the ADRs change", "before I push the plan", "pre-review my design doc", or is about to open or update a plan-first or ADR merge request. Only the user's own documents, never the whole register.
---

# ADR and plan check

Checks the documents the user wrote, not the register. Goal: nothing a reviewer could block on
for citations or ADR readings.

## Steps

1. **Pick the documents.** Paths the user gave, else the `.md` files the current branch adds
   or changes (`git diff --name-only <base>...HEAD -- '*.md'`). Confirm the list in one line.

2. **Find the register.** A git checkout holding `docs/decisions/adr-NNN-<slug>.md`. Use
   `$ADR_REGISTER`, else your memory, else ask. Don't guess between two checkouts.

3. **Run the drift script** from this skill's folder:

   ```bash
   perl "<skill folder>/scripts/adr-drift.pl" --register "<register>" doc1.md doc2.md
   ```

   It fetches `origin/master` and uses the newest register SHA in the documents as the stamp,
   else the newest date beside "checked" or "read on". If it finds none:
   - a doc inside the register (a new ADR or amendment): pass `--since $(git merge-base HEAD origin/master)`;
   - a plan or design doc: ask the user when they last read the ADRs, and pass `--since <date>`.

4. **Triage the report.** For each item:

   | Finding | What to do |
   | --- | --- |
   | NOT ON master | Fine when it links to the draft's pull request and calls it a draft or Proposed. A bare number with no link: fix. A wrong number: fix. |
   | CHANGED | Read the diff: `git -C <register> diff <since> origin/master -- <adr file>`. Wording only: fix any quote, then restamp. Decision or scope changed and the doc relies on it: rework that reasoning (must fix). |
   | ADDED after the stamp | The doc cites an ADR it was never checked against. Read it, then check every claim about it (step 5). |
   | STATUS | Update the stated status. If a Proposed ADR became Accepted, it now binds: re-check the departures (step 6). |
   | QUOTE | Replace with the decision in your own words plus the link. Quote only when the exact wording is the point, and then copy it fresh. |
   | POSITIONAL | Replace "§3", "rule 10", "line 40" with what the rule says, in a few words. |
   | ADRs added, not cited | Read title and services. If one covers a service or behaviour the doc designs, read it and treat it as cited. |
   | Leftovers | `$1`, TODO, TBD, `ADR-XXX`: fix every one. Also check the lists around them for gaps in numbering. |

5. **Verify each claim about an ADR.** The script can't. List every sentence that says an ADR
   places, allows, rejects, requires, owns, moves or defers something. Read the current text at
   `origin/master` and mark each Holds, Wrong or Partly. Over about ten ADRs, split them across
   subagents, a few ADRs each, giving them the claims and the register paths. Traps that reviewers
   catch:
   - **"Rejected because X, and X doesn't apply here."** Still a departure. The ADR rejected it.
   - **Amendments override the base text.** Read the whole file, including amendment sections
     and the history, not only the Decision.
   - **Direction.** "Moves into the shared package" versus "moves into its own domain".
   - **Entry rules.** A register or package often admits only what two callers use today. A
     planned caller doesn't count.
   - **Status.** A Proposed ADR binds nothing yet, but say so when you lean on it.
   - **Scope.** Check the ADR's `services:`. An ADR for other services doesn't bind this one,
     but it may bind the frontend or a shared contract the doc also designs.

6. **Check the departures** (design docs and plans). List every place the doc differs from an
   ADR, a pattern or an engineering rule. Each one must:
   - appear in the departure table (or the doc's equivalent), against the right ADR;
   - have an approval item;
   - be marked "ADR first" when the ADR is Accepted, or when it says changing it needs an ADR;
   - be in the start gate. The gate names exactly the "ADR first" items, no more and no fewer.

   Then cross-check the design doc and the plan. The same IDs and the same marks, and the same
   list in the MR body when there is one.

7. **Report.** One table, worst first, in three groups:
   - Must fix: a wrong claim, an unmarked or ungated departure, a changed decision the doc
     relies on, a leftover.
   - Should fix: a stale quote, a status, a positional citation, an unlinked draft.
   - Fine.

   Each row gives the document line, the finding and the fix. Follow the user's writing rules.

8. **Fix on request.** Apply what the user approves. Then restamp: one line with the date and the
   register SHA you checked, with the SHA under References. Run the script again. It should
   report nothing changed.

## Notes

- Writing so the next check is quiet: link, don't quote. Cite the decision, not its position.
  Reason about each ADR in one document, and link to that reasoning from the others.
- For a new ADR in the register, the register's own validator checks numbering, frontmatter and
  the index. This skill checks content only. Run both.
- The script matches patterns. A hit is a lead, not a verdict, and a clean run says nothing about
  step 5 or step 6.
