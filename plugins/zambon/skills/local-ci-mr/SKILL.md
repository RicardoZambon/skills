---
name: local-ci-mr
description: Check out a cost-management MR branch, run scripts/local-ci.ps1, and record the result as a note on the GitLab MR. Use when the user asks to "run local CI" / "run local-ci" on a branch or MR, "record the local-ci result in the MR", or is about to merge a cost-management MR while the heavy CI jobs are suspended to `when: manual`.
argument-hint: <branch-name | MR number>
allowed-tools: [Bash, Read, Grep, mcp__claude_ai_GitLab__list_merge_requests, mcp__claude_ai_GitLab__get_merge_request, mcp__claude_ai_GitLab__save_note]
---

# Local CI → MR

The rule lives in `cost-management/.gitlab-ci.yml` in the block headed
`TEMPORARY: the four heavy jobs are SUSPENDED to when: manual`:

> Run local-ci and record the result on any MR that merges while this block stands.
> For anything touching the write path, that is not optional.

The four suspended jobs are `test`, `lifecycle-e2e`, `fidelity-gate` and `spread-tpd-fidelity`.
`scripts/local-ci.ps1` runs all four, so the MR's evidence is the local-ci run.

## Steps

1. **Confirm the rule still applies.** `grep -n "SUSPENDED to .when: manual" .gitlab-ci.yml`.
   If the block is gone, hosted CI covers the jobs again. Tell the user; local-ci is optional.

2. **Check out the branch.** Repo: `~/workspace/Contruent/cost-management`
   (remote `gitlab.com:aresprism/microservices/cost-management`).
   - Run `git status --porcelain` first. If the tree is dirty, stop and ask. Never stash or discard.
   - `git fetch origin <branch> && git checkout <branch>`, then confirm it is up to date with
     `origin/<branch>`. Record `git rev-parse --short HEAD`: the note must name the commit it graded.
   - Given an MR number, get `sourceBranch` from `get_merge_request`.

3. **Find the MR.** Call `list_merge_requests` with `project_id: aresprism/microservices/cost-management`
   and `search: <ticket key>` (or match by `sourceBranch`). Keep the `iid`.

4. **Run the full pipeline.** No `-Skip*` switches unless the user asks for them; a skip needs a
   stated reason plus `-AcceptPartial`. The run takes a long time (Docker image builds, seed, e2e,
   `dotnet test`, fidelity), so run it in the background and log to the scratchpad:
   ```bash
   cd ~/workspace/Contruent/cost-management && \
   pwsh -NoProfile -File scripts/local-ci.ps1 > <scratchpad>/local-ci-<ticket>.log 2>&1; \
   echo "EXIT=$?" >> <scratchpad>/local-ci-<ticket>.log
   ```
   Use `run_in_background: true` with a long timeout (7200000 ms). Wait for the completion
   notification. Don't poll.
   - The script no longer needs `contruent-frontend` (ADR-069). The lifecycle spec and archives
     are in this repo.

5. **Read the result.** It's at the end of the log:
   - `── Summary ──`: one `[v]`/`[X]` line per step, with timings or counts.
   - `── CI coverage ──`: `ran N of M CI jobs`, plus any `NOT RUN` or `UNMAPPED` lines.
   - `EXIT=` is 0 only when every step passed and coverage is complete (or the partial run was
     accepted).
   - Pull the key numbers from the log: `dotnet test` passed/failed/skipped, lifecycle e2e
     tests passed, fidelity gate result.
   - On a failure, find the failing step's output. Then check whether `main` fails the same
     way before you blame the branch (see the !458 precedent). Say which it is.

6. **Record it on the MR.** Post a top-level note with `save_note` (`project_id` +
   `merge_request_iid`). Don't edit the description unless the user asks. Use this format:
   ```markdown
   ## Local CI — `scripts/local-ci.ps1` (<PASS | FAIL | PARTIAL>)

   Recorded per the `.gitlab-ci.yml` suspension rule: `test`, `lifecycle-e2e`, `fidelity-gate` and
   `spread-tpd-fidelity` are `when: manual`, so this local run is their only execution.

   - **Commit:** `<short sha>` (`<branch>`)
   - **Invocation:** `pwsh scripts/local-ci.ps1` <flags, or "(no flags — full run)">
   - **CI coverage:** ran N of M CI jobs
   - **Exit code:** <n>

   | Step | Result |
   |---|---|
   | <each Summary line, verbatim> | <OK … / FAIL …> |

   <Failures: which step, the error, and whether it reproduces on main.>
   ```
   Report the numbers exactly as the log has them. If a step failed or didn't run, the note says so.
   Never post PASS on a non-zero exit.

7. **Report back.** Give the user the verdict, `ran N of M`, and a link to the note. The branch
   stays checked out. Tell the user which branch they were on before.

## Notes

- `-SkipFidelity`, `-SkipBuild` and `-SkipE2E` each make the run partial. Without
  `-AcceptPartial` the script exits 1 on purpose (CEPM-4128). A partial run is recorded as PARTIAL,
  never as a pass.
- An `UNMAPPED` CI job always fails the run. That's drift between `.gitlab-ci.yml` and
  `$ciJobCoverage` in the script. Report it; don't work around it.
- Docker must be running, and ports 5100/15433 must be free. Stale `cost-*` containers from
  another branch are fine because step 2 runs down + up.
