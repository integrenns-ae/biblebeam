#!/usr/bin/env node
// Erzeugt supabase/seed_v2_phrases.sql aus data/questions_raw_v2_phrases.json
// (zweisprachige Phrasen-Fragen, DE+EN index-gleich). Spielt NUR neue Fragen ein
// (status='approved', stabile IDs v2p-NNNN, on conflict do nothing) – die
// bestehenden 3000 bleiben unberuehrt. Optionen werden je Frage deterministisch
// gemischt, damit die richtige Antwort nicht immer auf Position 0 steht.
//
// Aufruf:  node scripts/build_import_v2.mjs
// Danach (Import, NICHT Teil dieses Skripts):
//   psql "<conn>" -v ON_ERROR_STOP=1 -f supabase/seed_v2_phrases.sql
//   ./scripts/refresh-assets.sh     # Assets aus der DB neu bauen
//   git commit + ./scripts/deploy.sh

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '..')
const SRC = resolve(ROOT, 'data/questions_raw_v2_phrases.json')
const OUT = resolve(ROOT, 'supabase/seed_v2_phrases.sql')
const CHUNK = 800
const LEVEL = { easy: 1, medium: 2, hard: 3 }

const md5 = (s) => createHash('md5').update(s).digest('hex')
const uuid = (s) => {
  const h = md5(s)
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`
}
const q = (s) => "'" + String(s).replace(/'/g, "''") + "'"
const slugify = (t) =>
  String(t).toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '')

const TESTAMENTS = new Set(['OT', 'NT', 'General'])
const BOOKS = new Set(['1 Corinthians','1 John','1 Kings','1 Peter','1 Samuel','2 Corinthians','2 John','2 Kings','2 Peter','2 Samuel','3 John','Acts','Amos','Chronicles','1 Chronicles','2 Chronicles','Colossians','Corinthians','Daniel','Deuteronomy','Ecclesiastes','Ephesians','Esther','Exodus','Ezekiel','Ezra','Galatians','Genesis','Gospels','Habakkuk','Haggai','Hebrews','Hosea','Isaiah','James','Jeremiah','Job','Joel','John','Jonah','Joshua','Jude','Judges','Lamentations','Leviticus','Luke','Malachi','Mark','Matthew','Micah','Nahum','Nehemiah','Numbers','Obadiah','Peter','Philemon','Philippians','Proverbs','Psalms','Revelation','Romans','Ruth','Song of Songs','Thessalonians','1 Thessalonians','2 Thessalonians','Timothy','1 Timothy','2 Timothy','Titus','Zechariah','Zephaniah'])
const kindOf = (tag) =>
  TESTAMENTS.has(tag) ? 'testament' : BOOKS.has(tag) ? 'book' : 'type'

// Deterministische Mischung der Indizes 0..3, ausgesaet aus der Frage-ID.
function shuffledOrder(seedStr) {
  let s = parseInt(md5(seedStr).slice(0, 8), 16) >>> 0
  const rnd = () => ((s = (s * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff)
  const a = [0, 1, 2, 3]
  for (let i = 3; i > 0; i--) {
    const j = Math.floor(rnd() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

const items = JSON.parse(readFileSync(SRC, 'utf8')).questions

const tagMap = new Map() // slug -> {tag, kind}
const cats = [], catTr = [], questions = [], qTr = [], opts = [], optTr = [], qCat = []

items.forEach((it, n) => {
  const id = 'v2p-' + String(n + 1).padStart(4, '0')
  const qid = uuid('q:' + id)
  const difficulty = LEVEL[it.level] || 2
  questions.push(`(${q(qid)}, ${difficulty}, 'approved', 'phrase-v2')`)
  qTr.push(`(${q(qid)}, 'de', ${q(it.q_de.trim())})`)
  qTr.push(`(${q(qid)}, 'en', ${q(it.q_en.trim())})`)

  // Optionen gemischt einsetzen, Paar DE/EN zusammenhalten.
  const order = shuffledOrder(id)
  order.forEach((src, pos) => {
    const oid = uuid('opt:' + id + ':' + pos)
    const isCorrect = src === it.answer_index
    opts.push(`(${q(oid)}, ${q(qid)}, ${isCorrect}, ${pos})`)
    optTr.push(`(${q(oid)}, 'de', ${q(String(it.options_de[src]).trim())})`)
    optTr.push(`(${q(oid)}, 'en', ${q(String(it.options_en[src]).trim())})`)
  })

  for (const tag of it.categories) {
    const slug = slugify(tag)
    if (!tagMap.has(slug)) tagMap.set(slug, { tag, kind: kindOf(tag) })
    qCat.push(`(${q(qid)}, ${q(uuid('cat:' + slug))})`)
  }
})

let sort = 1000 // Offset, damit es nicht mit bestehenden sort-Werten kollidiert
for (const [slug, { tag, kind }] of tagMap) {
  const cid = uuid('cat:' + slug)
  cats.push(`(${q(cid)}, ${q(slug)}, ${q(kind)}, ${sort++})`)
  catTr.push(`(${q(cid)}, 'en', ${q(tag)})`)
}

function batch(table, cols, rows, conflict) {
  const out = []
  for (let i = 0; i < rows.length; i += CHUNK)
    out.push(`insert into public.${table} (${cols}) values\n${rows.slice(i, i + CHUNK).join(',\n')}\non conflict ${conflict};`)
  return out
}

const lines = ['-- AUTO-GENERIERT (build_import_v2.mjs) – 2000 Phrasen-Fragen, NUR neue Zeilen', 'begin;']
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
console.log(`✔ supabase/seed_v2_phrases.sql: ${items.length} Fragen, ${tagMap.size} Kategorien, ${questions.length} Frage-Zeilen, ${opts.length} Optionen`)
