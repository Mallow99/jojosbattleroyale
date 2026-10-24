// Renders preview frames with the preinstalled Playwright Chromium.
// Usage: node tools/preview/capture.mjs <scene.json> <outDir> [frameStep] [only=0,5,9]
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../..");
const [sceneArg, outDir, stepArg, onlyArg] = process.argv.slice(2);
const step = Number(stepArg || 1);
const only = onlyArg ? onlyArg.split(",").map(Number) : null;
const files = {
  "/viewer.html": path.join(root, "tools/preview/viewer.html"),
  "/viewer.js": path.join(root, "tools/preview/viewer.js"),
  "/scene.json": path.resolve(sceneArg),
  "/StarPlatinumMorph.glb": path.join(root, "artifacts/preview/StarPlatinumMorph.glb"),
};
const types = { ".html": "text/html", ".js": "text/javascript", ".json": "application/json", ".glb": "model/gltf-binary" };
const threeRoot = path.join(root, ".tools/preview/node_modules/three");
const server = http.createServer((req, res) => {
  const pathname = new URL(req.url, "http://x").pathname;
  let file = files[pathname];
  if (!file && pathname.startsWith("/three/")) {
    const candidate = path.normalize(path.join(threeRoot, pathname.slice(7)));
    if (candidate.startsWith(threeRoot) && fs.existsSync(candidate)) file = candidate;
  }
  if (!file) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { "content-type": types[path.extname(file)] });
  fs.createReadStream(file).pipe(res);
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const port = server.address().port;
fs.mkdirSync(outDir, { recursive: true });
const browser = await chromium.launch({ args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on("console", (m) => { if (m.type() === "error") console.error("page:", m.text()); });
page.on("pageerror", (e) => console.error("page error:", e.message));
await page.goto(`http://127.0.0.1:${port}/viewer.html`);
await page.waitForFunction(() => window.ready === true, null, { timeout: 120000 });
const count = await page.evaluate(() => window.frameCount);
const indices = only || Array.from({ length: Math.ceil(count / step) }, (_, i) => i * step);
let n = 0;
for (const i of indices) {
  await page.evaluate((k) => window.renderFrame(k), i);
  await page.locator("#stage").screenshot({ path: path.join(outDir, `frame_${String(n).padStart(4, "0")}.png`) });
  n++;
}
console.log(`Captured ${n} frames to ${outDir}`);
await browser.close();
server.close();
