#!/usr/bin/env node
// Usage: node capture.mjs <html> <outDir> [--playwright /path/to/node_modules/playwright]
// Opens the page, walks every step of every diagram, saves one screenshot per step
// and fails on console errors or text that overflows its node box.
import { mkdirSync } from 'node:fs'
import { createRequire } from 'node:module'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'

const [html, outDir] = process.argv.slice(2)
const pwIdx = process.argv.indexOf('--playwright')
const pwPath = pwIdx > -1 ? process.argv[pwIdx + 1] : 'playwright'
const { chromium } = createRequire(import.meta.url)(pwPath)

mkdirSync(outDir, { recursive: true })
const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 1600, height: 900 } })
const errors = []
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()))
page.on('pageerror', (e) => errors.push(String(e)))
await page.goto(pathToFileURL(resolve(html)).href)
await page.waitForSelector('html[data-ready="1"]')

const ids = await page.evaluate(() => window.__flow.ids())
let shots = 0
const overflow = []
for (let d = 0; d < ids.length; d++) {
  await page.evaluate((i) => window.__flow.select(i), d)
  const steps = await page.evaluate(() => window.__flow.steps())
  const bad = await page.evaluate(() => [...document.querySelectorAll('.node')].flatMap((g) => {
    const r = g.querySelector('rect').getBBox()
    return [...g.querySelectorAll('text')].filter((t) => { const b = t.getBBox(); return b.x < r.x + 2 || b.x + b.width > r.x + r.width - 2 || b.y < r.y || b.y + b.height > r.y + r.height }).map((t) => `${g.dataset.id}: ${t.textContent}`)
  }))
  overflow.push(...bad.map((b) => `${ids[d]} ${b}`))
  const hidden = await page.evaluate(() => {
    const rects = [...document.querySelectorAll('.node rect')].map((r) => ({ id: r.parentNode.dataset.id, x: +r.getAttribute('x'), y: +r.getAttribute('y'), w: +r.getAttribute('width'), h: +r.getAttribute('height') }))
    return [...document.querySelectorAll('.edge text')].flatMap((t) => {
      const b = t.getBBox()
      return rects.filter((r) => b.x < r.x + r.w && r.x < b.x + b.width && b.y < r.y + r.h && r.y < b.y + b.height).map((r) => `edge label "${t.textContent}" overlaps node ${r.id}`)
    })
  })
  overflow.push(...hidden.map((h) => `${ids[d]} ${h}`))
  for (let s = 0; s < steps; s++) {
    await page.evaluate((i) => window.__flow.go(i), s)
    await page.waitForTimeout(350)
    await page.screenshot({ path: `${outDir}/${String(d + 1).padStart(2, '0')}-${ids[d]}-${String(s + 1).padStart(2, '0')}.png` })
    shots++
  }
}
await browser.close()
console.log(`${shots} screenshots in ${outDir}`)
if (overflow.length) console.error('TEXT OVERFLOW:\n' + overflow.join('\n'))
if (errors.length) console.error('CONSOLE ERRORS:\n' + errors.join('\n'))
process.exitCode = overflow.length || errors.length ? 1 : 0
