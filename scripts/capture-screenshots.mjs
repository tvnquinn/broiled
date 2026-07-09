import { chromium } from "playwright";
import { fileURLToPath } from "url";
import path from "path";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const wireframes = `file://${path.join(root, "wireframes.html")}`;
const outDir = path.join(root, "docs", "screenshots");
const frames = ["frame-01", "frame-02", "frame-03", "frame-04", "frame-08", "frame-09", "frame-10a", "frame-11"];

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1500, height: 1200 } });
await page.goto(wireframes);
await page.waitForTimeout(500);

for (const id of frames) {
  const phone = page.locator(`#${id} .phone`);
  await phone.scrollIntoViewIfNeeded();
  await phone.screenshot({ path: path.join(outDir, `${id}.png`) });
}

await browser.close();
console.log(`Captured ${frames.length} screenshots to docs/screenshots/`);
