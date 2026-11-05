#!/usr/bin/env node
// Serve the rendered page on localhost so it can be checked in a browser before publishing.
// The published artifact needs a claude.ai sign-in; this does not.
//
// Usage: node serve.mjs <directory> [port]   then open http://localhost:<port>/<file>.html

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize, resolve } from 'node:path';

const root = resolve(process.argv[2] || '.');
const port = Number(process.argv[3] || 4517);
const types = { '.html': 'text/html; charset=utf-8', '.json': 'application/json', '.js': 'text/javascript', '.css': 'text/css' };

createServer(async (request, response) => {
  const path = normalize(decodeURIComponent(new URL(request.url, 'http://localhost').pathname));
  const file = join(root, path);
  if (!file.startsWith(root)) {
    response.writeHead(403).end();
    return;
  }
  try {
    const body = await readFile(file);
    // The artifact host wraps the page in a skeleton; mimic it so the page renders the same.
    const page = extname(file) === '.html'
      ? `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"><style>body{margin:0;font:14px system-ui}</style></head><body>${body}</body></html>`
      : body;
    response.writeHead(200, { 'content-type': types[extname(file)] || 'application/octet-stream', 'cache-control': 'no-store' }).end(page);
  } catch {
    response.writeHead(404).end('not found');
  }
}).listen(port, () => console.log(`serving ${root} on http://localhost:${port}`));
