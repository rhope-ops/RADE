// Render assets/logo/logo-K.svg to PNG (headless Chromium via Playwright). Run after scripts/build_logo.py:
//   node scripts/render_logo.js
// 512: site logo and thumbnail (SharePoint scales it). 128: the RADE window (shown at 40 px; 128 px covers 3 x 40). 64: header size. 32 and 16: icons and browser tabs.
const {chromium} = require('playwright'); const fs = require('fs'); const path = require('path');
const dir = path.join(__dirname, '..', 'assets', 'logo');
(async () => {
  const b = await chromium.launch();
  const svg = fs.readFileSync(path.join(dir, 'logo-K.svg'), 'utf8');
  for (const size of [512, 128, 64, 32, 16]) {
    const p = await b.newPage({viewport: {width: size, height: size}});
    await p.setContent(`<html><body style="margin:0;background:transparent">${svg.replace('width="512" height="512"', `width="${size}" height="${size}"`)}</body></html>`);
    await p.screenshot({path: path.join(dir, `logo-K-${size}.png`), omitBackground: true, clip: {x: 0, y: 0, width: size, height: size}});
    await p.close();
  }
  await b.close();
})();
