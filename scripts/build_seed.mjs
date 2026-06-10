#!/usr/bin/env node
// Erzeugt supabase/seed.sql (v3, BATCHED) aus dem rohen Fragenkatalog.
// Roh-Tags als Kategorien (kind), n:m, Schwierigkeit, status='approved'.
// Gebündelte Mehrzeilen-INSERTs -> ~50 statt ~38.000 Statements (Sekunden statt Minuten).
//
// Aufruf:  node scripts/build_seed.mjs

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'

import { buildPack, classifyTag, slugify } from './lib/transform.mjs'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '..')
const SRC = resolve(ROOT, 'data/questions_raw.json')
const OUT = resolve(ROOT, 'supabase/seed.sql')
const CHUNK = 800

function uuid(str) {
  const h = createHash('md5').update(str).digest('hex')
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`
}
const q = (s) => "'" + String(s).replace(/'/g, "''") + "'"

function batch(table, cols, rows, conflict) {
  const out = []
  for (let i = 0; i < rows.length; i += CHUNK) {
    const slice = rows.slice(i, i + CHUNK)
    out.push(
      `insert into public.${table} (${cols}) values\n${slice.join(',\n')}\non conflict ${conflict};`,
    )
  }
  return out
}

const raw = JSON.parse(readFileSync(SRC, 'utf8')).questions
const pack = buildPack(raw)

// Distinct Roh-Tags
const tagMap = new Map()
for (const item of pack.questions)
  for (const tag of item.tags) {
    const s = slugify(tag)
    if (!tagMap.has(s)) tagMap.set(s, { tag, kind: classifyTag(tag) })
  }

const cats = [],
  catTr = [],
  questions = [],
  qTr = [],
  opts = [],
  optTr = [],
  qCat = []

let sort = 0
for (const [slug, { tag, kind }] of tagMap) {
  const cid = uuid('cat:' + slug)
  cats.push(`(${q(cid)}, ${q(slug)}, ${q(kind)}, ${sort++})`)
  catTr.push(`(${q(cid)}, 'en', ${q(tag)})`)
}

for (const item of pack.questions) {
  const qid = uuid('q:' + item.id)
  questions.push(`(${q(qid)}, ${item.difficulty}, 'approved', 'seed-import')`)
  qTr.push(`(${q(qid)}, 'en', ${q(item.question)})`)
  item.options.forEach((opt, idx) => {
    const oid = uuid('opt:' + item.id + ':' + idx)
    opts.push(`(${q(oid)}, ${q(qid)}, ${opt === item.answer}, ${idx})`)
    optTr.push(`(${q(oid)}, 'en', ${q(opt)})`)
  })
  for (const tag of item.tags) qCat.push(`(${q(qid)}, ${q(uuid('cat:' + slugify(tag)))})`)
}

const lines = ['-- AUTO-GENERIERT (build_seed.mjs v3, batched)', 'begin;']
lines.push(...batch('categories', 'id, slug, kind, sort', cats, '(slug) do nothing'))
lines.push(...batch('category_translations', 'category_id, lang, name', catTr, 'do nothing'))
lines.push(...batch('questions', 'id, difficulty, status, source', questions, '(id) do nothing'))
lines.push(...batch('question_translations', 'question_id, lang, prompt', qTr, 'do nothing'))
lines.push(...batch('answer_options', 'id, question_id, is_correct, sort', opts, '(id) do nothing'))
lines.push(...batch('answer_option_translations', 'option_id, lang, text', optTr, 'do nothing'))
lines.push(...batch('question_categories', 'question_id, category_id', qCat, 'do nothing'))
lines.push('commit;')

mkdirSync(dirname(OUT), { recursive: true })
writeFileSync(OUT, lines.join('\n') + '\n')
console.log(
  `✔ supabase/seed.sql (batched): ${tagMap.size} Kategorien, ${pack.questions.length} Fragen, ${lines.length} Statements`,
)
