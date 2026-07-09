import { chromium } from "playwright";
import { fileURLToPath } from "url";
import path from "path";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const wireframes = `file://${path.join(root, "wireframes.html")}`;
const outDir = path.join(root, "docs", "screenshots");
const frames = [
  "frame-01",
  "frame-02",
  "frame-03",
  "frame-04",
  "frame-08",
  "frame-09",
  "frame-10a",
  "frame-11",
];

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1500, height: 1200 } });
await page.goto(wireframes);
await page.waitForTimeout(500);

for (const id of frames) {
  const phone = page.locator(`#${id} .phone`);
  await phone.scrollIntoViewIfNeeded();
  await phone.screenshot({ path: path.join(outDir, `${id}.png`) });
}

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

await pageEl.screenshot({ path: path.join(outDir, "wireframes-rail.png") });

await browser.close();
console.log(`Captured ${frames.length} frame screenshots and wireframes-rail.png`);
