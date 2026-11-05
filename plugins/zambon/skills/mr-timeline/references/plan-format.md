# Plan format

One file per feature: `~/.claude/mr-timeline/features/<KEY>/plan.json`. `build.mjs` checks it against
that feature's `collected.json`. `feature`, `collect` and `lanes` are required.

```json
{
  "feature": {
    "key": "CEPM-4502",
    "url": "https://aresprism.atlassian.net/browse/CEPM-4502",
    "status": "In Progress",
    "title": "Enterprise Periods",
    "summary": "Two sentences a manager can read: what the feature delivers and how."
  },
  "collect": {
    "keys": ["CEPM-4502", "CEPM-4520"],
    "author": "ricardozambon-contruent",
    "since": "2026-10-01",
    "include": [],
    "exclude": []
  },
  "lanes": [
    {
      "id": "planning",
      "title": "Planning",
      "subtitle": "ADRs and plans",
      "items": [
        { "ref": "aresprism/microservices/cost-management!610", "label": "Short name", "note": "One sentence." },
        {
          "external": {
            "ref": "prism-g2 PR 491",
            "url": "https://dev.azure.com/.../pullrequest/491",
            "title": "ADR-032 amendment: ...",
            "state": "merged | opened | closed | pending",
            "mergedAt": "2026-11-03T14:36:07Z",
            "statusLabel": "Open on Azure DevOps",
            "wait": "status not read",
            "reviewersText": "optional plain line"
          },
          "note": "One sentence."
        }
      ],
    }
  ],
  "folded": [{ "ref": "aresprism/contruent-frontend!2787", "note": "Merged into the !2775 branch." }],
  "next": [{ "key": "CEPM-6425", "url": "https://...", "title": "Permission gating", "status": "Backlog" }],
  "notes": ["Extra footer lines."]
}
```

- `collect` tells `refresh.mjs` how to find the feature's MRs: every MR in the group whose title or
  description names one of `keys`, by `author`, created after `since`; plus `include`, minus
  `exclude` (full refs).
- `ref` must be a full reference present in the collected data.
- An `external` item (an Azure DevOps ADR PR, say) can carry `reviewers`, entered from what the
  user reports, in the collected shape: `{ "name", "state": "REVIEWED" | "APPROVED", "rounds",
  "wave", "turn": "reviewer" | "author" | "done" | "held", "waitingSince": UTC ISO }`. A `held`
  reviewer also names `heldBy` (e.g. "ADR-016"): they won't act until that item moves, so they
  neither wait nor approve. The page then reads the item like an MR: status, wave, waits and the
  over-a-day warning. Convert the user's local time to UTC. Without `reviewers`, `statusLabel`
  and `reviewersText` are shown as given.
- `folded` and `next` are not shown on the page. Keep `folded` anyway: it records why a collected
  MR has no node, and the renderer refuses a plan that drops an MR silently.
- Lanes are the stages, in this order: `planning`, `shared`, `backend`, `frontend`. Leave out a
  stage with no MRs, or keep it empty; the page hides it either way. There is no Bugs lane.
- `rows` (top level) are the horizontal lanes: work streams, such as
  `{ "id": "delivery", "title": "Feature delivery" }`, then one per follow-up or tech-debt stream
  the user names (`{ "id": "debt", "title": "Tech debt", "subtitle": "CEPM-6628" }`). Bug MRs go in a
  `{ "id": "bugs", "title": "Bugs" }` row, each in the stage of the repo it changes. Each item
  sets `row`; without one it goes to the first row. Add a row only when the user asks for it.
- `blocked` on an item (a short reason) turns it red. An MR GitLab marks as blocked by an open MR
  turns red on its own. Use `blocked` for what GitLab cannot see: a pinned dev build, an ADR
  that must merge first.
- `dependsOn` on an item (a list of MR refs or external `ref`s) draws an arrow from each one to
  this card: red while the blocker is open, faint dashed blue once it merged. GitLab's own
  "blocked by" links are drawn without being listed. Take dependencies from the MR descriptions
  ("must not merge before", "pins a dev build of", "after"), not from guesses.
- `omit` (top level, full refs) leaves collected MRs off the page entirely, when the user asks to
  remove one. Use `folded` instead when it was merged into another MR or closed.
- `hideReviewers` (top level, usernames) drops those reviewers from the page and from the wave and
  wait figures. Default for the user: `["mmaltby"]`.
- `step` on an item overrides its number, e.g. `"8a"` for MRs that merge together.
- `label` overrides the MR title on the page; keep the GitLab title when it already reads plainly.
