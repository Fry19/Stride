// Renders SVG files to PNG with headless Chromium.
// Usage: node render.mjs <out-dir> <width> <height> <file.svg>...
// Needs Playwright; a global install works with NODE_PATH set to the global node_modules.
import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { basename, join } from "node:path";

const { chromium } = createRequire(import.meta.url)("playwright");

const [outDir, width, height, ...files] = process.argv.slice(2);
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
const page = await browser.newPage({ viewport: { width: Number(width), height: Number(height) } });
for (const file of files) {
  const svg = readFileSync(file, "utf8");
  await page.setContent(
    `<html><body style="margin:0;background:transparent">${svg.replace("<svg ", `<svg width="${width}" height="${height}" `)}</body></html>`);
  await page.screenshot({ path: join(outDir, basename(file, ".svg") + ".png"), omitBackground: true });
}
await browser.close();
