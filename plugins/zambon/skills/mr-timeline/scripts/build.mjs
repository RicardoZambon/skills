#!/usr/bin/env node
// Assemble the board: the fixed view page plus board.json, built from the data home.
//
// Usage: node build.mjs [--home ~/.claude/mr-timeline] --out <folder>
//
// Data home layout:
//   board.json                       { title, url, features: [{ key, status: "active" | "closed" }] }
//   features/<KEY>/plan.json         rows, lanes, items, dependsOn, collect settings
//   features/<KEY>/collected.json    the latest GitLab facts, written by refresh.mjs
//
// The page (assets/board.html) never holds data, so changing data never touches the view.

import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const args = Object.fromEntries(
  process.argv.slice(2).reduce((pairs, token, index, all) => {
    if (token.startsWith('--')) pairs.push([token.slice(2), all[index + 1] ?? '']);
    return pairs;
  }, [])
);
const home = args.home || join(homedir(), '.claude', 'mr-timeline');
if (!args.out) {
  console.error('usage: build.mjs [--home <data home>] --out <folder>');
  process.exit(2);
}
const readJson = (path) => JSON.parse(readFileSync(path, 'utf8'));

// The checks a plan must pass against its collected data. Returns a list of problems.
export function checkPlan(plan, data) {
  const problems = [];
  const known = new Set(data.mrs.map((mr) => mr.ref));
  const placed = new Set();
  const ids = new Set();
  const rowIds = new Set((plan.rows ?? []).map((row) => row.id));
  for (const lane of plan.lanes ?? []) {
    for (const item of lane.items ?? []) {
      if (item.row && !rowIds.has(item.row)) problems.push(`an item names row "${item.row}", which plan.rows does not define`);
      if (item.ref) {
        if (!known.has(item.ref)) problems.push(`plan names ${item.ref}, which the collected data does not hold`);
        if (placed.has(item.ref)) problems.push(`${item.ref} is placed twice`);
        placed.add(item.ref);
        ids.add(item.ref);
      } else if (item.external?.ref) {
        ids.add(item.external.ref);
      } else {
        problems.push(`an item in lane "${lane.title}" has neither ref nor external.ref`);
      }
    }
  }
  for (const lane of plan.lanes ?? []) {
    for (const item of lane.items ?? []) {
      for (const dependency of item.dependsOn ?? []) {
        if (!ids.has(dependency)) problems.push(`${item.ref || item.external.ref} depends on ${dependency}, which is not on the board`);
      }
    }
  }
  for (const item of plan.folded ?? []) placed.add(item.ref);
  for (const ref of plan.omit ?? []) placed.add(ref);
  for (const ref of known) if (!placed.has(ref)) problems.push(`${ref} was collected but is in no lane, not folded and not omitted`);
  return problems;
}

const board = readJson(join(home, 'board.json'));
const features = [];
const problems = [];
for (const entry of board.features ?? []) {
  const folder = join(home, 'features', entry.key);
  const plan = readJson(join(folder, 'plan.json'));
  const collectedPath = join(folder, 'collected.json');
  if (!existsSync(collectedPath)) {
    problems.push(`${entry.key}: no collected.json yet; run refresh.mjs`);
    continue;
  }
  const data = readJson(collectedPath);
  for (const problem of checkPlan(plan, data)) problems.push(`${entry.key}: ${problem}`);
  features.push({ key: entry.key, status: entry.status || 'active', plan, data });
}
if (problems.length) {
  console.error(problems.map((line) => `- ${line}`).join('\n'));
  process.exit(1);
}

const generatedAt = features.map((feature) => feature.data.collectedAt).sort().at(-1) ?? new Date().toISOString();
mkdirSync(args.out, { recursive: true });
const here = dirname(fileURLToPath(import.meta.url));
copyFileSync(join(here, '..', 'assets', 'board.html'), join(args.out, 'index.html'));
writeFileSync(join(args.out, 'board.json'), JSON.stringify({ title: board.title, generatedAt, features }));
const active = features.filter((feature) => feature.status !== 'closed').length;
console.log(`built ${args.out}: ${features.length} features (${active} active)`);
