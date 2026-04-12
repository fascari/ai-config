import puppeteer from 'puppeteer';
import { resolve, dirname, basename, extname } from 'path';
import { fileURLToPath } from 'url';
import { readFileSync, existsSync, statSync, mkdirSync } from 'fs';
import { execSync } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));

const args = process.argv.slice(2);
const compress = args.includes('--compress');
const filteredArgs = args.filter(a => a !== '--compress');

const inputPath = filteredArgs[0]
  ? resolve(filteredArgs[0])
  : null;

const outputPath = filteredArgs[1]
  ? resolve(filteredArgs[1])
  : inputPath
    ? resolve(dirname(inputPath), `${basename(inputPath, '.html')}.pdf`)
    : null;

if (!inputPath) {
  console.error('Usage: node generate-doc-pdf.mjs <input.html> [output.pdf] [--compress]');
  process.exit(1);
}

if (!existsSync(inputPath)) {
  console.error(`❌ File not found: ${inputPath}`);
  process.exit(1);
}

const outputDir = dirname(outputPath);
if (!existsSync(outputDir)) {
  mkdirSync(outputDir, { recursive: true });
}

const rawPath = outputPath.replace(/\.pdf$/, '-raw.pdf');

console.log(`📄 Converting: ${inputPath}`);
console.log(`💾 Output:     ${outputPath}`);

const browser = await puppeteer.launch({ headless: true });
const page    = await browser.newPage();

// A4 width at 96dpi = 794px — matches exactly what Chrome uses when printing
await page.setViewport({ width: 794, height: 1123, deviceScaleFactor: 1 });

// Force print media — makes layout identical to Chrome's print dialog
await page.emulateMediaType('print');

const html = readFileSync(inputPath, 'utf8');
await page.setContent(html, { waitUntil: 'networkidle0', timeout: 30000 });

const usedPath = compress ? rawPath : outputPath;

await page.pdf({
  path: usedPath,
  format: 'A4',
  printBackground: true,
  preferCSSPageSize: false,
  margin: { top: '0', bottom: '0', left: '0', right: '0' },
});

await browser.close();

const rawSize = (statSync(usedPath).size / 1e6).toFixed(2);
console.log(`📊 Size: ${rawSize} MB`);

if (compress) {
  console.log('🔧 Compressing with ghostscript...');
  execSync([
    'gs',
    '-dBATCH', '-dNOPAUSE', '-dQUIET',
    '-sDEVICE=pdfwrite',
    '-dCompatibilityLevel=1.4',
    '-dPDFSETTINGS=/ebook',
    '-dDetectDuplicateImages',
    '-r150x150',
    `-sOutputFile=${outputPath}`,
    rawPath,
  ].join(' '));

  const { unlinkSync } = await import('fs');
  unlinkSync(rawPath);

  const finalSize = (statSync(outputPath).size / 1e6).toFixed(2);
  console.log(`✅ Compressed: ${finalSize} MB`);
} else {
  console.log(`✅ PDF saved → ${outputPath}`);
}

