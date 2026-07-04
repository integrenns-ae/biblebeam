#!/usr/bin/env node
// Erzeugt assets/questions_en.json + questions_de.json AUS der Supabase-DB
// (Single Source of Truth). Liest /tmp/db_dump.json (von psql), leitet die
// Lichtpfad-Regionen aus den Buch-Tags ab (DB-Slugs) und schreibt das
// Pack-Format wie die bisherigen Assets.
//
// Aufruf: psql ... -o /tmp/db_dump.json -f ... ; node scripts/build_assets_from_db.mjs

import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')

const REGIONS = [
  ['torah', 'Law (Torah)'], ['history', 'History of Israel'],
  ['wisdom', 'Wisdom & Poetry'], ['prophets', 'Prophets'],
  ['gospels', 'Gospels (Jesus)'], ['church', 'Early Church'],
  ['revelation', 'Revelation'], ['general', 'General Bible'],
]
const BOOK_REGION = {}
const add = (r, books) => books.forEach((b) => (BOOK_REGION[b] = r))
add('torah', ['genesis', 'exodus', 'leviticus', 'numbers', 'deuteronomy'])
add('history', ['joshua', 'judges', 'ruth', '1-samuel', '2-samuel', 'samuel', '1-kings', '2-kings', 'kings', 'chronicles', '1-chronicles', '2-chronicles', 'ezra', 'nehemiah', 'esther'])
add('wisdom', ['job', 'psalms', 'proverbs', 'ecclesiastes', 'song-of-songs'])
add('prophets', ['isaiah', 'jeremiah', 'lamentations', 'ezekiel', 'daniel', 'hosea', 'joel', 'amos', 'obadiah', 'jonah', 'micah', 'nahum', 'habakkuk', 'zephaniah', 'haggai', 'zechariah', 'malachi'])
add('gospels', ['matthew', 'mark', 'luke', 'john', 'gospels'])
add('church', ['acts', 'romans', '1-corinthians', '2-corinthians', 'corinthians', 'galatians', 'ephesians', 'philippians', 'colossians', '1-thessalonians', '2-thessalonians', 'thessalonians', '1-timothy', '2-timothy', 'timothy', 'titus', 'philemon', 'hebrews', 'james', '1-peter', '2-peter', 'peter', '1-john', '2-john', '3-john', 'jude'])
add('revelation', ['revelation'])

const rows = JSON.parse(readFileSync('/tmp/db_dump.json', 'utf8'))

for (const lang of ['en', 'de']) {
  const questions = []
  const regionCounts = {}
  for (const q of rows) {
    const prompt = (q.prompts?.[lang] || '').trim()
    if (!prompt) continue
    const opts = (q.options || [])
      .filter((o) => (o.texts?.[lang] || '').trim())
      .sort((a, b) => (a.sort ?? 0) - (b.sort ?? 0))
    const texts = opts.map((o) => o.texts[lang].trim())
    let answer = null
    opts.forEach((o, i) => { if (o.correct) answer = texts[i] })
    if (texts.length < 2 || !answer) continue

    const regions = new Set()
    for (const c of q.cats || []) {
      if (c.kind === 'book') regions.add(BOOK_REGION[c.slug] || 'general')
    }
    if (regions.size === 0) regions.add('general')
    for (const r of regions) regionCounts[r] = (regionCounts[r] || 0) + 1

    const reference = (q.explanations?.[lang] || '').trim() // Bibelstelle (optional)
    questions.push({
      id: q.id,
      categories: [...regions],
      difficulty: q.difficulty ?? 2,
      question: prompt,
      options: texts,
      answer,
      ...(reference ? { reference } : {}),
    })
  }
  const categories = REGIONS
    .filter(([slug]) => regionCounts[slug])
    .map(([slug, name]) => ({ slug, name, count: regionCounts[slug] }))
  const pack = { version: 2, lang, categories, questions }
  const out = resolve(ROOT, `assets/questions_${lang}.json`)
  writeFileSync(out, JSON.stringify(pack, null, 2))
  console.log(`✔ assets/questions_${lang}.json: ${questions.length} Fragen, ${categories.length} Regionen`)
}
