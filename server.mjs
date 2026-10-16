import { createReadStream, existsSync, readFileSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, normalize, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const port = Number(process.env.PORT || 8080);
const programDirectory = resolve(process.env.PROGRAM_DIRECTORY || fileURLToPath(new URL('./', import.meta.url)));
const manifestPath = join(programDirectory, 'programs.json');
const publicDirectory = fileURLToPath(new URL('./public/', import.meta.url));

function sendJson(response, status, value, headOnly = false) {
  const body = JSON.stringify(value);
  response.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store'
  });
  response.end(headOnly ? undefined : body);
}

function fetchPrograms() {
  const programs = JSON.parse(readFileSync(manifestPath, 'utf8'));
  if (!Array.isArray(programs)) throw new Error('programs.json must contain an array');
  const slugs = new Set();
  return programs.map(program => {
    if (!program.title || !program.category || !program.description) throw new Error('Every program must include title, category, and description');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(program.releaseDate) || Number.isNaN(Date.parse(`${program.releaseDate}T00:00:00Z`))) throw new Error(`Invalid release date for ${program.title}`);
    if (!['basic', 'machine-code'].includes(program.language)) throw new Error(`Invalid language for ${program.title}`);
    if (!Array.isArray(program.controls) || !program.controls.length || program.controls.some(control => !Array.isArray(control.keys) || !control.keys.length || !control.description)) {
      throw new Error(`Invalid controls for ${program.title}`);
    }
    if (!program.path?.toLowerCase().endsWith('.prg')) throw new Error('Every program must reference a PRG file');
    const filePath = resolve(programDirectory, program.path);
    if (!filePath.startsWith(programDirectory + sep) || !existsSync(filePath) || !statSync(filePath).isFile()) {
      throw new Error(`Program file is missing: ${program.path}`);
    }
    const sourcePath = program.source;
    const expectedExtension = program.language === 'basic' ? '.bas' : '.asm';
    if (!sourcePath?.toLowerCase().endsWith(expectedExtension)) throw new Error(`Invalid source file for ${program.title}`);
    const sourceFilePath = resolve(programDirectory, sourcePath);
    if (!sourceFilePath.startsWith(programDirectory + sep) || !existsSync(sourceFilePath) || !statSync(sourceFilePath).isFile()) {
      throw new Error(`Source file is missing: ${sourcePath}`);
    }
    const slug = program.path.split('/')[0];
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug) || slugs.has(slug)) throw new Error(`Invalid or duplicate program slug: ${slug}`);
    slugs.add(slug);
    return {
      ...program,
      slug,
      size: statSync(filePath).size
    };
  });
}

function sendProgram(response, programPath, headOnly = false) {
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
  if (headOnly) response.end();
  else createReadStream(filePath).pipe(response);
}

function sendSource(response, programPath, headOnly = false) {
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
  if (headOnly) response.end();
  else createReadStream(filePath).pipe(response);
}

function serveStatic(response, pathname, headOnly = false) {
  const isProgramPage = /^\/program\/[a-z0-9]+(?:-[a-z0-9]+)*\/?$/.test(pathname);
  const isCategoryPage = /^\/category\/[a-z0-9]+(?:-[a-z0-9]+)*\/?$/.test(pathname);
  const requested = pathname === '/' || isProgramPage || isCategoryPage ? 'index.html' : pathname.slice(1);
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
  if (headOnly) response.end();
  else createReadStream(filePath).pipe(response);
  return true;
}

createServer(async (request, response) => {
  try {
    const url = new URL(request.url, `http://${request.headers.host || 'localhost'}`);
    const headOnly = request.method === 'HEAD';
    if (request.method !== 'GET' && !headOnly) {
      response.setHeader('Allow', 'GET, HEAD');
      sendJson(response, 405, { error: 'Method not allowed' });
    } else if (url.pathname === '/api/programs') {
      sendJson(response, 200, { programs: fetchPrograms() }, headOnly);
    } else if (url.pathname === '/api/program') {
      sendProgram(response, url.searchParams.get('path') || '', headOnly);
    } else if (url.pathname === '/api/source') {
      sendSource(response, url.searchParams.get('path') || '', headOnly);
    } else if (!serveStatic(response, url.pathname, headOnly)) {
      sendJson(response, 404, { error: 'Not found' }, headOnly);
    }
  } catch (error) {
    console.error(error);
    if (!response.headersSent) sendJson(response, 500, { error: 'Unable to read the program library' });
    else response.end();
  }
}).listen(port, '0.0.0.0', () => {
  console.log(`C64 Program Collection listening on port ${port}`);
});

