// Render RADE's logo SVGs in assets/logo to PNG (headless Chromium via Playwright).
//   node scripts/render_logo.js            renders every mark below
//   node scripts/render_logo.js rho-usaf   renders one mark (use it so a mark you did not change keeps its PNG bytes:
//                                          the render is not byte-stable, and the engine checks logo-rho-128.png by SHA-256)
// Marks:
//   logo-rho  Rho Bold (USAF-B); its SVG comes from scripts/build_logo.py. The engine reads logo-rho-128.png (the window).
//   rho-usaf  Rho, USAF version (Logo Studies canvas, the Administrator, 2026-11-19); its SVG is copied from the canvas,
//             not built here. The RADE page uses it now; the engine moves to it in a later engine release.
// Sizes: 512 site logo and thumbnail; 128 the window (shown at 64 px) and the page at 2x; 64 the page at 1x; 32 and 16 icons.
const {chromium} = require('playwright'); const fs = require('fs'); const path = require('path');
const dir = path.join(__dirname, '..', 'assets', 'logo');
const MARKS = ['logo-rho', 'rho-usaf'];
const SIZES = [512, 128, 64, 32, 16];

/**
 * Render one mark's SVG to a PNG at each size in SIZES, with a transparent background.
 * @param {import('playwright').Browser} browser  an open Chromium
 * @param {string} mark  the file name of the SVG without ".svg" (one of MARKS)
 * @returns {Promise<void>}  writes assets/logo/<mark>-<size>.png
 */
async function renderMark(browser, mark) {
  const svg = fs.readFileSync(path.join(dir, `${mark}.svg`), 'utf8');
  for (const size of SIZES) {
    const p = await browser.newPage({viewport: {width: size, height: size}});
    await p.setContent(`<html><body style="margin:0;background:transparent">${svg.replace('width="512" height="512"', `width="${size}" height="${size}"`)}</body></html>`);
    await p.screenshot({path: path.join(dir, `${mark}-${size}.png`), omitBackground: true, clip: {x: 0, y: 0, width: size, height: size}});
    await p.close();
  }
}

(async () => {
  const wanted = process.argv.slice(2);
  const unknown = wanted.filter((m) => !MARKS.includes(m));
  if (unknown.length) { console.error(`unknown mark: ${unknown.join(', ')} (marks: ${MARKS.join(', ')})`); process.exit(2); }
  const b = await chromium.launch();
  for (const mark of (wanted.length ? wanted : MARKS)) await renderMark(b, mark);
  await b.close();
})();
