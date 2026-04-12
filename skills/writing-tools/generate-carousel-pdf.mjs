import puppeteer from 'puppeteer';
import { resolve, dirname, basename, extname } from 'path';
import { fileURLToPath } from 'url';
import { createServer } from 'http';
import { readFileSync, existsSync, statSync, unlinkSync } from 'fs';
import { execSync } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));

const articleDir = process.argv[2]
  ? resolve(process.argv[2])
  : resolve(__dirname, 'medium/green-tea-gc');

const articleName = basename(articleDir);
const html = resolve(articleDir, 'carousel.html');
const out  = resolve(articleDir, `${articleName}.pdf`);
const raw  = resolve(articleDir, `${articleName}-raw.pdf`);

if (!existsSync(html)) {
  console.error(`carousel.html not found in ${articleDir}`);
  process.exit(1);
}

const mime = {
  '.html': 'text/html',
  '.png':  'image/png',
  '.jpg':  'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif':  'image/gif',
  '.svg':  'image/svg+xml',
  '.css':  'text/css',
  '.js':   'application/javascript',
};

const server = createServer((req, res) => {
  const filePath = resolve(articleDir, '.' + req.url.split('?')[0]);
  if (!existsSync(filePath)) { res.writeHead(404); res.end(); return; }
  const ext = extname(filePath).toLowerCase();
  res.writeHead(200, { 'Content-Type': mime[ext] || 'application/octet-stream' });
  res.end(readFileSync(filePath));
});

await new Promise(r => server.listen(0, '127.0.0.1', r));
const { port } = server.address();

const browser = await puppeteer.launch({ headless: true });
const page    = await browser.newPage();

await page.goto(`http://127.0.0.1:${port}/carousel.html`, { waitUntil: 'networkidle0' });

const slideCount = await page.evaluate(
  () => document.querySelectorAll('.slide').length
);

console.log(`Slides found: ${slideCount}`);

await page.pdf({
  path: raw,
  width:  '1080px',
  height: '1080px',
  printBackground: true,
  pageRanges: `1-${slideCount}`,
});

await browser.close();
server.close();

console.log(`Raw PDF: ${(statSync(raw).size / 1e6).toFixed(0)} MB — compressing with ghostscript...`);

execSync([
  'gs',
  '-dBATCH', '-dNOPAUSE', '-dQUIET',
  '-sDEVICE=pdfwrite',
  '-dCompatibilityLevel=1.5',
  '-dPDFSETTINGS=/printer',
  '-dDownsampleColorImages=true', '-dColorImageResolution=300',
  '-dDownsampleGrayImages=true',  '-dGrayImageResolution=300',
  '-dDownsampleMonoImages=true',  '-dMonoImageResolution=300',
  `-sOutputFile=${out}`,
  raw,
].join(' '));

unlinkSync(raw);
console.log(`PDF saved → ${out} (${(statSync(out).size / 1e6).toFixed(1)} MB)`);
