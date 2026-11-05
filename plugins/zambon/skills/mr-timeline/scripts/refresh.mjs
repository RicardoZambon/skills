#!/usr/bin/env node
// Re-collect GitLab facts for the board's active features, then build the page.
//
// Usage: node refresh.mjs [--home ~/.claude/mr-timeline] --out <folder> [--feature CEPM-4502]
//
// Each plan.json carries how to find its MRs:
//   "collect": { "keys": ["CEPM-4502", ...], "author": "<gitlab user>", "since": "2026-10-01",
//                "include": [<full refs>], "exclude": [<full refs>] }

import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';
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
  console.error('usage: refresh.mjs [--home <data home>] --out <folder> [--feature KEY]');
  process.exit(2);
}
const here = dirname(fileURLToPath(import.meta.url));
const board = JSON.parse(readFileSync(join(home, 'board.json'), 'utf8'));
const targets = (board.features ?? []).filter((entry) => (args.feature ? entry.key === args.feature : entry.status !== 'closed'));
if (!targets.length) {
  console.error(args.feature ? `no feature ${args.feature} in board.json` : 'no active features in board.json');
  process.exit(1);
}

for (const entry of targets) {
  const folder = join(home, 'features', entry.key);
  const plan = JSON.parse(readFileSync(join(folder, 'plan.json'), 'utf8'));
  const collect = plan.collect ?? {};
  if (!collect.keys?.length && !collect.include?.length) {
    console.error(`${entry.key}: plan.collect has no keys or include list`);
    process.exit(1);
  }
  const options = [
    ['keys', collect.keys], ['author', collect.author], ['since', collect.since], ['group', collect.group],
    ['include', collect.include], ['exclude', collect.exclude]
  ].filter(([, value]) => (Array.isArray(value) ? value.length : value))
    .flatMap(([name, value]) => [`--${name}`, Array.isArray(value) ? value.join(',') : value]);
  const output = execFileSync(process.execPath, [join(here, 'collect.mjs'), ...options], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  writeFileSync(join(folder, 'collected.json'), output);
  console.log(`${entry.key}: collected ${JSON.parse(output).mrs.length} MRs`);
}

execFileSync(process.execPath, [join(here, 'build.mjs'), '--home', home, '--out', args.out], { stdio: 'inherit' });
