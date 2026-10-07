import { createReadStream, existsSync, readFileSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const port = Number(process.env.PORT || 8080);
const programDirectory = resolve(process.env.PROGRAM_DIRECTORY || fileURLToPath(new URL('./', import.meta.url)));
const manifestPath = join(programDirectory, 'programs.json');
const publicDirectory = fileURLToPath(new URL('./public/', import.meta.url));

function sendJson(response, status, value) {
  const body = JSON.stringify(value);
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store'
  });
  response.end(body);
}

function fetchPrograms() {
  const programs = JSON.parse(readFileSync(manifestPath, 'utf8'));
  if (!Array.isArray(programs)) throw new Error('programs.json must contain an array');
  return programs.map(program => {
    if (!program.path?.toLowerCase().endsWith('.prg')) throw new Error('Every program must reference a PRG file');
    const filePath = resolve(programDirectory, program.path);
    if (!filePath.startsWith(programDirectory + sep) || !existsSync(filePath) || !statSync(filePath).isFile()) {
      throw new Error(`Program file is missing: ${program.path}`);
    }
    const sourcePath = program.source || program.path.replace(/\.prg$/i, '.bas');
    const sourceFilePath = resolve(programDirectory, sourcePath);
    return {
      ...program,
      source: sourceFilePath.startsWith(programDirectory + sep) && existsSync(sourceFilePath) ? sourcePath : null,
      size: statSync(filePath).size
    };
  });
}

function sendProgram(response, programPath) {
  const programs = fetchPrograms();
  if (!programs.some(program => program.path === programPath)) {
    sendJson(response, 404, { error: 'Program not found' });
    return;
  }

  const filePath = resolve(programDirectory, programPath);
  response.writeHead(200, {
    'Content-Type': 'application/octet-stream',
    'Content-Length': statSync(filePath).size,
    'Content-Disposition': `inline; filename="${programPath.split('/').at(-1)}"`,
    'Cache-Control': 'no-store'
  });
  createReadStream(filePath).pipe(response);
}

function sendSource(response, programPath) {
  const program = fetchPrograms().find(entry => entry.path === programPath);
  if (!program?.source) {
    sendJson(response, 404, { error: 'Program source not found' });
    return;
  }
  const filePath = resolve(programDirectory, program.source);
  response.writeHead(200, {
    'Content-Type': 'text/plain; charset=utf-8',
    'Content-Length': statSync(filePath).size,
    'Cache-Control': 'no-store'
  });
  createReadStream(filePath).pipe(response);
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
      sendJson(response, 200, { programs: fetchPrograms() });
    } else if (url.pathname === '/api/program') {
      sendProgram(response, url.searchParams.get('path') || '');
    } else if (url.pathname === '/api/source') {
      sendSource(response, url.searchParams.get('path') || '');
    } else if (!serveStatic(response, url.pathname)) {
      sendJson(response, 404, { error: 'Not found' });
    }
  } catch (error) {
    console.error(error);
    if (!response.headersSent) sendJson(response, 500, { error: 'Unable to read the program library' });
    else response.end();
  }
}).listen(port, '0.0.0.0', () => {
  console.log(`C64 BASIC runner listening on port ${port}`);
});

