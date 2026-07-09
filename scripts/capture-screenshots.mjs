import { chromium } from "playwright";
import { fileURLToPath } from "url";
import path from "path";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const inputName = process.argv[2] || "wireframe_phase0.html";
const outputName = inputName.replace(/\.html$/, "-rail.png");
const wireframes = `file://${path.join(root, inputName)}`;
const outDir = path.join(root, "docs", "screenshots");

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1500, height: 1200 } });
await page.goto(wireframes);
await page.waitForTimeout(500);

await page.addStyleTag({
  content: `
    .page { max-width: none; padding-bottom: 48px; }
    .rail { flex-wrap: wrap; overflow-x: visible; row-gap: 28px; }
  `,
});
await page.waitForTimeout(100);

const pageEl = page.locator(".page");
const box = await pageEl.boundingBox();
if (!box) throw new Error("Could not measure .page for rail screenshot");

await page.setViewportSize({
  width: Math.max(1500, Math.ceil(box.width) + 64),
  height: Math.ceil(box.height) + 64,
});
await page.waitForTimeout(100);

await pageEl.screenshot({ path: path.join(outDir, outputName) });

await browser.close();
console.log(`Captured ${outputName}`);
