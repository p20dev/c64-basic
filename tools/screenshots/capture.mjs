import { readFile, stat, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import process from 'node:process';
import { chromium } from 'playwright';
import { PNG } from 'pngjs';

const root = '/programs';
const baseUrl = (process.env.SCREENSHOT_BASE_URL || 'http://c64-basic:8080').replace(/\/$/, '');
const args = process.argv.slice(2);
const force = args.includes('--force');
const requestedSlugs = args.filter(argument => !argument.startsWith('--'));
const programs = JSON.parse(await readFile(resolve(root, 'programs.json'), 'utf8'));
const recipes = JSON.parse(await readFile(resolve(root, 'screenshots.json'), 'utf8'));
const selected = programs.filter(program => {
  const slug = program.path.split('/')[0];
  return requestedSlugs.length === 0 || requestedSlugs.includes(slug);
});
const knownSlugs = new Set(programs.map(program => program.path.split('/')[0]));
const missingRecipes = [...knownSlugs].filter(slug => !Object.hasOwn(recipes, slug));
const unknownRecipes = Object.keys(recipes).filter(slug => slug !== '$default' && !knownSlugs.has(slug));

if (missingRecipes.length || unknownRecipes.length) {
  if (missingRecipes.length) console.error(`Missing screenshot recipes: ${missingRecipes.join(', ')}`);
  if (unknownRecipes.length) console.error(`Unknown screenshot recipes: ${unknownRecipes.join(', ')}`);
  process.exit(1);
}

if (!selected.length) {
  console.error('No matching programs. Pass a program slug or omit it to capture the full collection.');
  process.exit(1);
}

const browser = await chromium.launch({
  headless: true,
  args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist']
});
const context = await browser.newContext({
  viewport: { width: 1280, height: 1100 },
  deviceScaleFactor: 1,
  acceptDownloads: false
});
const page = await context.newPage();
page.setDefaultTimeout(30_000);

function slugOf(program) {
  return program.path.split('/')[0];
}

function outputPath(program) {
  return resolve(root, slugOf(program), 'screenshot.png');
}

function normalizeKey(key) {
  const names = { SPACE: 'Space', RETURN: 'Enter', ENTER: 'Enter', ESC: 'Escape' };
  return names[key.toUpperCase()] || (key.length === 1 ? key.toLowerCase() : key);
}

function imageStats(buffer) {
  const png = PNG.sync.read(buffer);
  const colors = new Set();
  let visiblePixels = 0;
  for (let offset = 0; offset < png.data.length; offset += 16) {
    const red = png.data[offset];
    const green = png.data[offset + 1];
    const blue = png.data[offset + 2];
    const alpha = png.data[offset + 3];
    if (alpha > 0 && red + green + blue > 18) visiblePixels++;
    if (colors.size < 512) colors.add(`${red >> 3},${green >> 3},${blue >> 3},${alpha >> 5}`);
  }
  return { width: png.width, height: png.height, colors: colors.size, visiblePixels };
}

async function captureCanvas(canvas, path) {
  const box = await canvas.boundingBox();
  if (!box) throw new Error('emulator canvas has no visible bounds');
  return page.screenshot({
    path,
    type: 'png',
    clip: { x: box.x, y: box.y, width: box.width, height: box.height }
  });
}

async function waitForPicture(canvas, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  let lastStats;
  while (Date.now() < deadline) {
    const buffer = await captureCanvas(canvas);
    lastStats = imageStats(buffer);
    if (lastStats.colors >= 2 && lastStats.visiblePixels >= 100) return lastStats;
    await page.waitForTimeout(750);
  }
  throw new Error(`emulator never produced a visible frame (${JSON.stringify(lastStats)})`);
}

async function captureVisibleFrame(canvas, timeoutMs = 10_000) {
  const deadline = Date.now() + timeoutMs;
  let lastStats;
  while (Date.now() < deadline) {
    const buffer = await captureCanvas(canvas);
    lastStats = imageStats(buffer);
    if (lastStats.colors >= 2 && lastStats.visiblePixels >= 100) return { buffer, stats: lastStats };
    await page.waitForTimeout(250);
  }
  throw new Error(`captured frames look blank (${JSON.stringify(lastStats)})`);
}

async function exists(path) {
  try {
    await stat(path);
    return true;
  } catch {
    return false;
  }
}

let failures = 0;
for (const program of selected) {
  const slug = slugOf(program);
  const destination = outputPath(program);
  const recipeOverride = recipes[slug];
  const recipe = recipes.$default ? { ...recipes.$default, ...recipeOverride } : recipeOverride;
  if (!recipe || !recipeOverride) {
    console.error(`FAIL ${slug}: no screenshot recipe`);
    failures++;
    continue;
  }
  if (!force && await exists(destination)) {
    console.log(`SKIP ${slug}: screenshot.png already exists`);
    continue;
  }

  try {
    console.log(`OPEN ${slug}`);
    await page.goto(`${baseUrl}/program/${slug}`, { waitUntil: 'domcontentloaded', timeout: 60_000 });
    const canvas = page.locator('canvas.ejs_canvas');
    await canvas.waitFor({ state: 'visible', timeout: 60_000 });
    await waitForPicture(canvas, recipe.readyTimeoutMs || 60_000);
    await page.waitForTimeout(recipe.settleBeforeActionsMs || 5000);
    await canvas.click({ position: { x: 320, y: 240 } });
    await page.mouse.move(10, 10);
    await page.waitForTimeout(1500);

    for (const action of recipe.actions || []) {
      if (action.waitBeforeMs) await page.waitForTimeout(action.waitBeforeMs);
      if (action.text !== undefined) await page.keyboard.type(String(action.text), { delay: 120 });
      else if (action.key) await page.keyboard.press(normalizeKey(action.key), { delay: 120 });
      else throw new Error('screenshot action must contain key or text');
      if (action.waitAfterMs) await page.waitForTimeout(action.waitAfterMs);
    }
    if (recipe.captureAfterMs) await page.waitForTimeout(recipe.captureAfterMs);

    const { buffer, stats } = await captureVisibleFrame(canvas);
    await writeFile(destination, buffer);
    console.log(`SAVED ${slug}/screenshot.png (${stats.width}x${stats.height}, ${stats.colors} sampled colors)`);
  } catch (error) {
    failures++;
    console.error(`FAIL ${slug}: ${error.message}`);
  }
}

await browser.close();
if (failures) {
  console.error(`${failures} screenshot${failures === 1 ? '' : 's'} failed.`);
  process.exit(1);
}
console.log(`Screenshot run complete: ${selected.length} program${selected.length === 1 ? '' : 's'} selected.`);
