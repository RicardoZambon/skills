---
name: mr-timeline
description: Keep the user's daily merge board - one page showing every active feature's MRs across the GitLab repositories as a git-style graph, by stage (Planning, Shared packages, Backend, Frontend) and work stream (feature delivery, tech debt, bugs), with blockers, review waves and waits. Use when the user asks to refresh or check the board, see where their MRs stand, add a feature or Jira key to it, close a feature, change which MR depends on which, add a tech-debt row or a not-yet-opened MR, or wants a status overview, timeline or kanban for their manager.
---

# Merge board

One published page, one data home. **Data and view never mix:** refreshing, adding a feature or
moving a dependency changes only JSON in the data home. The view (`assets/board.html`) changes only
when the user asks for a visual change, and it never names a feature.

## Where things live

- **Data home** `~/.claude/mr-timeline/`
  - `board.json`: `{ title, url, features: [{ key, status: "active" | "closed" }] }`. `url` is the
    published page; always republish there.
  - `features/<KEY>/plan.json`: the feature's header, how to find its MRs (`collect`), rows, lanes,
    items and dependencies. Shape in `references/plan-format.md`.
  - `features/<KEY>/collected.json`: the latest GitLab facts. Written by `refresh.mjs` only.
- **Scripts** (this skill's `scripts/`): `collect.mjs` (one feature's GitLab facts),
  `refresh.mjs` (collect every active feature, then build), `build.mjs` (check every plan against
  its data, write `index.html` + `board.json`), `serve.mjs` (local preview).
- **Build output**: `<scratchpad>/merge-board/`. Publish needs it under the scratchpad.

## Tasks

**Refresh (the daily one).**

```bash
node "<skill>/scripts/refresh.mjs" --out "<scratchpad>/merge-board"
```

Then check the display and publish (below). Report in three lines at most: what merged since
last time, what waits longest on whom, what is blocked.

**Add a feature.** Read the Jira feature and its children (`key = X OR parent = X`), find its MRs
with a dry `collect.mjs` run, and read each open MR's description for merge-order lines ("must not
merge before", "pins a dev build of", "after"). Write `features/<KEY>/plan.json` with `collect`,
then add `{ key, status: "active" }` to `board.json`, then refresh.

**Adjust connections or layout data.** Edit only the feature's `plan.json`: `dependsOn`, `row`,
lanes, `omit`, `blocked`, labels and notes. Then `build.mjs` (no need to re-collect), check, publish.
Facts the user tells you that no API shows (who blocks an ADR, an offline decision) go in as
`blocked` or a note and stay until the user says otherwise.

**Close a feature.** Set its `status` to `"closed"` in `board.json`. Keep its folder. It folds into
"Closed features" at the bottom and stops being refreshed.

**Change the view.** Edit `assets/board.html` only, never a data file for a visual reason. Then
build and check with every feature on the board.

## Check the display, every time

The published page needs a claude.ai sign-in the browser pane does not have. Serve the build
folder with `serve.mjs` through a `preview_start` launch entry (never a Bash background job):
`node "<skill>/scripts/serve.mjs" "<scratchpad>" 4517`, then open
`http://localhost:4517/merge-board/index.html` at 1440 wide. Run `scripts/check-lines.js` in the
pane with `javascript_tool`: every feature must report "no crossings". Then screenshot each
feature and read it as the user would. A crossing is a view bug: fix it in `board.html`, never by
moving data around to dodge it. Fix, check again, then publish.

## Publish

Artifact tool, `file_path` = `<scratchpad>/merge-board/index.html`,
`files` = `{ "board.json": "<scratchpad>/merge-board/board.json" }`, `url` = `board.json`'s `url`.
On a first publish, `icon: "timeline"`, then write the URL into `board.json`.

## How the page reads

- Stages are Planning, Shared packages, Backend and Frontend. A stage with no MRs in a feature
  takes no column. Bugs and tech debt are work streams: rows, added only when the feature has them.
- One overview row per active feature: progress, merged, blocked, over a day, in review.
- Per feature, a git-style graph: stages are columns, work streams are rows, each track is a grey
  rail, each MR a dot coloured by state with an icon before its name. Red line: must merge first.
  A line that changes rail forks off its dot on its own curve and turns only between columns.
- **Blocked** = anything it depends on is still open (`dependsOn`, GitLab "blocked by"), or a
  `blocked` reason in the plan. A blocked MR shows only "Blocked · waits on …".
- A review wait past 24 hours is red, with a pulsing warning after the MR's name.
- **Wave** = one review round: a reviewer's notes between two pushes by the author. Mark
  (`mmaltby`) is left off through `hideReviewers`.
- A not-yet-opened MR (`external.state: "pending"`) is faded, with its incoming lines.
