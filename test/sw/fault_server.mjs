// Static server for public/safe/ with two injectable faults:
//   state.failShell  -> '/safe/' answers 503 (simulates a transient network failure)
//   state.swVersion  -> substituted into sw.js's __SW_BUILD__ token, so changing it
//                       makes the browser see a genuinely new service worker
//   state.swFile     -> which sw.js source to serve (fixed vs. pre-fix)
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(new URL('../../public/safe', import.meta.url).pathname);
const PORT = 4321;
export const state = { failShell: false, swVersion: 1, swFile: path.join(ROOT, 'sw.js') };

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.svg': 'image/svg+xml',
  '.png': 'image/png', '.webmanifest': 'application/manifest+json' };

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  let p = url.pathname;

  if (p === '/safe/' || p === '/safe/index.html') {
    if (state.failShell) { res.writeHead(503); res.end('injected failure'); return; }
    p = '/safe/index.html';
  }
  if (p === '/safe/sw.js') {
    const src = fs.readFileSync(state.swFile, 'utf8').replace('__SW_BUILD__', String(state.swVersion));
    res.writeHead(200, { 'content-type': 'text/javascript', 'cache-control': 'no-cache' });
    res.end(src);
    return;
  }
  const file = path.join(ROOT, p.replace(/^\/safe\//, ''));
  if (!file.startsWith(ROOT) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    res.writeHead(404); res.end('nf'); return;
  }
  res.writeHead(200, { 'content-type': TYPES[path.extname(file)] || 'application/octet-stream',
                       'cache-control': 'no-cache' });
  res.end(fs.readFileSync(file));
});
server.listen(PORT);
export default server;
