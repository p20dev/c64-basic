import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const port = Number(process.env.PORT || 8080);
const repository = (process.env.PROGRAM_REPOSITORY || 'https://git.p20.dev/christian/c64-basic').replace(/\/$/, '');
const branch = process.env.PROGRAM_BRANCH || 'main';
const publicDirectory = fileURLToPath(new URL('./public/', import.meta.url));
const repositoryMatch = repository.match(/^https:\/\/([^/]+)\/([^/]+)\/([^/]+)$/);

if (!repositoryMatch) {
  throw new Error('PROGRAM_REPOSITORY must look like https://host/owner/repository');
}

const [, repositoryHost, repositoryOwner, repositoryName] = repositoryMatch;
const apiBase = `https://${repositoryHost}/api/v1/repos/${encodeURIComponent(repositoryOwner)}/${encodeURIComponent(repositoryName)}`;

function sendJson(response, status, value) {
  const body = JSON.stringify(value);
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store'
  });
  response.end(body);
}

async function fetchPrograms() {
  const treeUrl = `${apiBase}/git/trees/${encodeURIComponent(branch)}?recursive=true`;
  const upstream = await fetch(treeUrl, { signal: AbortSignal.timeout(10000) });
  if (!upstream.ok) throw new Error(`Repository returned HTTP ${upstream.status}`);
  const tree = await upstream.json();
  return tree.tree
    .filter(entry => entry.type === 'blob' && entry.path.toLowerCase().endsWith('.prg'))
    .map(entry => ({ path: entry.path, size: entry.size }))
    .sort((left, right) => left.path.localeCompare(right.path));
}

async function proxyProgram(response, programPath) {
  const programs = await fetchPrograms();
  if (!programs.some(program => program.path === programPath)) {
    sendJson(response, 404, { error: 'Program not found' });
    return;
  }

  const encodedPath = programPath.split('/').map(encodeURIComponent).join('/');
  const rawUrl = `${repository}/raw/branch/${encodeURIComponent(branch)}/${encodedPath}`;
  const upstream = await fetch(rawUrl, { signal: AbortSignal.timeout(10000) });
  if (!upstream.ok) throw new Error(`Program download returned HTTP ${upstream.status}`);
  const bytes = Buffer.from(await upstream.arrayBuffer());
  response.writeHead(200, {
    'Content-Type': 'application/octet-stream',
    'Content-Length': bytes.length,
    'Content-Disposition': `inline; filename="${programPath.split('/').at(-1)}"`,
    'Cache-Control': 'no-store'
  });
  response.end(bytes);
}

function serveStatic(response, pathname) {
  const requested = pathname === '/' ? 'index.html' : pathname.slice(1);
  const filePath = normalize(join(publicDirectory, requested));
  if (!filePath.startsWith(publicDirectory) || !existsSync(filePath) || !statSync(filePath).isFile()) {
    return false;
  }
  const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8' };
  response.writeHead(200, {
    'Content-Type': types[extname(filePath)] || 'application/octet-stream',
    'Content-Length': statSync(filePath).size,
    'Cache-Control': 'no-cache'
  });
  createReadStream(filePath).pipe(response);
  return true;
}

createServer(async (request, response) => {
  try {
    const url = new URL(request.url, `http://${request.headers.host || 'localhost'}`);
    if (request.method !== 'GET') {
      sendJson(response, 405, { error: 'Method not allowed' });
    } else if (url.pathname === '/api/programs') {
      sendJson(response, 200, { repository, branch, programs: await fetchPrograms() });
    } else if (url.pathname === '/api/program') {
      await proxyProgram(response, url.searchParams.get('path') || '');
    } else if (!serveStatic(response, url.pathname)) {
      sendJson(response, 404, { error: 'Not found' });
    }
  } catch (error) {
    console.error(error);
    if (!response.headersSent) sendJson(response, 502, { error: 'Unable to reach the program repository' });
    else response.end();
  }
}).listen(port, '0.0.0.0', () => {
  console.log(`C64 BASIC runner listening on port ${port}`);
});

