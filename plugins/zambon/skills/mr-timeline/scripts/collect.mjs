#!/usr/bin/env node
// Collect review facts for a feature's GitLab merge requests, as JSON on stdout.
//
// Usage:
//   node collect.mjs --keys CEPM-4502,CEPM-4520 [--author <username>] [--group aresprism]
//                    [--since 2026-10-01] [--include <ref>,<ref>] [--exclude <ref>,<ref>]
//
// A <ref> is the full GitLab reference, e.g. aresprism/microservices/cost-management!613.
// Needs an authenticated `glab`. Facts only: categorising and ordering is the skill's job.

import { execFileSync } from 'node:child_process';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((pairs, token, index, all) => {
    if (token.startsWith('--')) pairs.push([token.slice(2), all[index + 1] ?? '']);
    return pairs;
  }, [])
);
const list = (value) => (value ? value.split(',').map((item) => item.trim()).filter(Boolean) : []);
const keys = list(args.keys);
const group = args.group || 'aresprism';
const author = args.author || '';
const since = args.since || '';
const include = list(args.include);
const exclude = new Set(list(args.exclude));

if (!keys.length && !include.length) {
  console.error('usage: collect.mjs --keys KEY[,KEY] [--author u] [--group g] [--since date] [--include ref] [--exclude ref]');
  process.exit(2);
}

function glab(path, extra = []) {
  const out = execFileSync('glab', ['api', path, ...extra], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  return JSON.parse(out);
}
function glabPaged(path) {
  const rows = [];
  for (let page = 1; page < 50; page++) {
    const sep = path.includes('?') ? '&' : '?';
    const batch = glab(`${path}${sep}per_page=100&page=${page}`);
    rows.push(...batch);
    if (batch.length < 100) break;
  }
  return rows;
}
function graphql(query) {
  return glab('graphql', ['-f', `query=${query}`]).data;
}
const enc = (path) => encodeURIComponent(path);
const parseRef = (ref) => {
  const match = ref.match(/^(.+)!(\d+)$/);
  if (!match) throw new Error(`not a full MR reference: ${ref}`);
  return { project: match[1], iid: match[2] };
};

// 1. Find candidate MRs: every MR in the group that mentions a key, plus explicit includes.
const refs = new Set(include);
for (const key of keys) {
  const query = [`search=${encodeURIComponent(key)}`, 'state=all', 'scope=all'];
  if (author) query.push(`author_username=${author}`);
  if (since) query.push(`created_after=${since}T00:00:00Z`);
  for (const mr of glabPaged(`groups/${enc(group)}/merge_requests?${query.join('&')}`)) {
    refs.add(mr.references.full);
  }
}
for (const ref of exclude) refs.delete(ref);

// 2. Per MR: metadata, reviewers, notes, and the derived review rounds.
const REVIEW_SYSTEM = /^(approved this merge request|requested changes|unapproved this merge request)/;
const PUSH = /^added \d+ commits?/;
const READY = /^marked this merge request as \*\*ready\*\*/;
const REQUEST = /^requested review from (.+)$/;

function reviewerFacts(username, state, notes, mrAuthor, readyAt, createdAt) {
  const events = [];
  for (const note of notes) {
    const who = note.author.username;
    const body = note.body.trim();
    if (who === username && (!note.system || REVIEW_SYSTEM.test(body))) {
      events.push({ at: note.created_at, kind: 'reviewer', body });
    } else if (who === mrAuthor && note.system && PUSH.test(body)) {
      events.push({ at: note.created_at, kind: 'push' });
    } else if (who === mrAuthor && !note.system) {
      events.push({ at: note.created_at, kind: 'reply' });
    } else if (note.system && REQUEST.test(body) && body.includes(`@${username}`)) {
      events.push({ at: note.created_at, kind: 'requested' });
    }
  }
  events.sort((left, right) => left.at.localeCompare(right.at));

  // A round is one burst of reviewer activity; a push by the author closes it.
  let rounds = 0;
  let pushedSinceReview = true;
  let lastReviewerAt = null;
  let lastHandoverAt = null;
  let requestedAt = null;
  for (const event of events) {
    if (event.kind === 'reviewer') {
      if (pushedSinceReview) rounds += 1;
      pushedSinceReview = false;
      lastReviewerAt = event.at;
    } else {
      if (event.kind === 'push') pushedSinceReview = true;
      if (event.kind === 'requested') requestedAt = event.at;
      if (event.kind === 'push' || event.kind === 'reply' || event.kind === 'requested') lastHandoverAt = event.at;
    }
  }

  let turn;
  let waitingSince;
  if (state === 'APPROVED') {
    turn = 'done';
    waitingSince = lastReviewerAt;
  } else if (!lastReviewerAt) {
    turn = 'reviewer';
    waitingSince = [requestedAt, readyAt, createdAt].filter(Boolean).sort().at(-1);
  } else if (lastHandoverAt && lastHandoverAt > lastReviewerAt) {
    turn = 'reviewer';
    waitingSince = lastHandoverAt;
  } else {
    turn = 'author';
    waitingSince = lastReviewerAt;
  }
  return {
    username,
    state,
    rounds,
    wave: turn === 'reviewer' ? rounds + 1 : rounds,
    turn,
    waitingSince,
    lastReviewerAt
  };
}

const results = [];
for (const ref of [...refs].sort()) {
  const { project, iid } = parseRef(ref);
  const mr = glab(`projects/${enc(project)}/merge_requests/${iid}`);
  const gql = graphql(`query { project(fullPath:"${project}") { mergeRequest(iid:"${iid}") {
    detailedMergeStatus headPipeline { status }
    approvedBy { nodes { username } }
    blockingMergeRequests { visibleMergeRequests { reference(full:true) state } }
    reviewers { nodes { username name mergeRequestInteraction { reviewState } } } } } }`).project.mergeRequest;
  const notes = glabPaged(`projects/${enc(project)}/merge_requests/${iid}/notes?sort=asc&order_by=created_at`);
  const mrAuthor = mr.author.username;
  const readyAt = notes.filter((note) => note.system && READY.test(note.body)).map((note) => note.created_at).at(-1) ?? null;

  const reviewers = gql.reviewers.nodes.map((node) =>
    ({ ...reviewerFacts(node.username, node.mergeRequestInteraction?.reviewState ?? 'UNREVIEWED', notes, mrAuthor, readyAt, mr.created_at), name: node.name })
  );
  const text = `${mr.title}\n${mr.description ?? ''}`;
  results.push({
    ref,
    project,
    repo: project.split('/').at(-1),
    iid: Number(iid),
    url: mr.web_url,
    title: mr.title,
    state: mr.state,
    draft: mr.draft,
    createdAt: mr.created_at,
    readyAt,
    mergedAt: mr.merged_at,
    closedAt: mr.closed_at,
    mergeStatus: gql.detailedMergeStatus,
    pipeline: gql.headPipeline?.status ?? null,
    approvedBy: gql.approvedBy.nodes.map((node) => node.username),
    blockedBy: gql.blockingMergeRequests?.visibleMergeRequests ?? [],
    labels: mr.labels,
    sourceBranch: mr.source_branch,
    jiraKeys: [...new Set(text.match(/\b[A-Z][A-Z0-9]+-\d+\b/g) ?? [])],
    descriptionStart: (mr.description ?? '').slice(0, 1200),
    reviewers
  });
}

console.log(JSON.stringify({ collectedAt: new Date().toISOString(), group, keys, mrs: results }, null, 2));
