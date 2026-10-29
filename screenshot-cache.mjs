import { createHash } from 'node:crypto';
import { readFileSync, statSync } from 'node:fs';
import { mkdir, stat, rename } from 'node:fs/promises';
import { join } from 'node:path';
import sharp from 'sharp';

const versions = new Map();
const pending = new Map();
const encoding = 'webp-q90-v1';

export function screenshotVersion(path) {
  const info = statSync(path);
  const signature = `${info.mtimeMs}:${info.ctimeMs}:${info.size}`;
  const cached = versions.get(path);
  if (cached?.signature === signature) return cached.version;
  const version = createHash('sha256').update(encoding).update(readFileSync(path)).digest('hex');
  versions.set(path, { signature, version });
  return version;
}

export async function cachedScreenshot(source, directory, version) {
  const destination = join(directory, `${version}.webp`);
  if (pending.has(destination)) return pending.get(destination);
  const conversion = (async () => {
    await mkdir(directory, { recursive: true });
    try { await stat(destination); return destination; }
    catch (error) { if (error.code !== 'ENOENT') throw error; }
    const temporary = `${destination}.${process.pid}.tmp`;
    await sharp(source).webp({ quality: 90 }).toFile(temporary);
    await rename(temporary, destination);
    return destination;
  })();
  pending.set(destination, conversion);
  try { return await conversion; }
  finally { pending.delete(destination); }
}
