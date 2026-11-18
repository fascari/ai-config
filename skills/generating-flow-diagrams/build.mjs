#!/usr/bin/env node
// Usage: node build.mjs [--title "Title"] [--lang pt|en] [--root /path/to/repo] [--flows dir] [--out out/index.html]
// Merges flows/*.json into template.html and checks the data before writing.
import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { homedir } from 'node:os'

const here = dirname(fileURLToPath(import.meta.url))
const arg = (name, fallback) => {
  const i = process.argv.indexOf(`--${name}`)
  return i > -1 ? process.argv[i + 1] : fallback
}
const title = arg('title', 'Flow diagrams')
const lang = arg('lang', 'pt')
const root = resolve(arg('root', process.cwd()))
const out = resolve(arg('out', join(here, 'out/index.html')))
const flowsDir = resolve(arg('flows', join(here, 'examples')))

const problems = []
const warn = (m) => problems.push(m)

const files = readdirSync(flowsDir).filter((f) => f.endsWith('.json')).sort()
const diagrams = files.map((f) => JSON.parse(readFileSync(join(flowsDir, f), 'utf8')))

const overlap = (a, b) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h

for (const d of diagrams) {
  const [cw, ch] = d.canvas || [1200, 600]
  const ids = new Set()
  const nodes = d.nodes.map((n) => ({ w: 170, h: 58, ...n }))
  for (const n of nodes) {
    if (ids.has(n.id)) warn(`${d.id}: duplicate node ${n.id}`)
    ids.add(n.id)
    if (n.x < 0 || n.y < 0 || n.x + n.w > cw || n.y + n.h > ch) warn(`${d.id}: node ${n.id} outside canvas`)
  }
  nodes.forEach((a, i) => nodes.slice(i + 1).forEach((b) => overlap(a, b) && warn(`${d.id}: nodes ${a.id} and ${b.id} overlap`)))
  const edgeIds = new Set()
  for (const e of d.edges) {
    if (edgeIds.has(e.id)) warn(`${d.id}: duplicate edge ${e.id}`)
    edgeIds.add(e.id)
    if (!ids.has(e.from) || !ids.has(e.to)) warn(`${d.id}: edge ${e.id} references a missing node`)
  }
  d.steps.forEach((s, i) => {
    for (const n of s.nodes || []) if (!ids.has(n)) warn(`${d.id} step ${i + 1}: unknown node ${n}`)
    for (const e of s.edges || []) if (!edgeIds.has(e)) warn(`${d.id} step ${i + 1}: unknown edge ${e}`)
    for (const src of s.src || []) {
      const p = src.startsWith('~') ? src.replace('~', homedir()) : resolve(root, src)
      if (!existsSync(p)) warn(`${d.id} step ${i + 1}: src not found: ${src}`)
    }
  })
  const used = new Set(d.steps.flatMap((s) => s.nodes || []))
  for (const id of ids) if (!used.has(id)) warn(`${d.id}: node ${id} is never highlighted`)
}

const tpl = readFileSync(join(here, 'template.html'), 'utf8')
const data = JSON.stringify({ lang, diagrams }).replace(/</g, '\\u003c')
const page = tpl.replaceAll('__TITLE__', title).replaceAll('__LANG__', lang === 'en' ? 'en' : 'pt-BR').replace('"__DATA__"', () => data)
mkdirSync(dirname(out), { recursive: true })
writeFileSync(out, page)
console.log(`wrote ${out} (${diagrams.length} diagrams)`)
if (problems.length) {
  console.error(problems.map((p) => `WARN ${p}`).join('\n'))
  process.exitCode = 1
}
