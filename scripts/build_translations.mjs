#!/usr/bin/env node
// Baut aus dem (bereits erzeugten) englischen Asset + der index-gleichen
// deutschen Rohdatei das deutsche Asset UND die DB-Übersetzungen (seed_de.sql).
//
// Prinzip: gleiche Frage-/Options-Reihenfolge wie EN, nur Text übersetzt.
//   - korrekte Antwort: exakt aus der DE-Datei (pro Frage)
//   - Ablenker: über Lexikon EN-Antwort -> DE-Antwort (jeder Ablenker ist
//     irgendwo eine korrekte Antwort -> hat eine DE-Entsprechung)
//
// Aufruf:  node scripts/build_questions.mjs && node scripts/build_translations.mjs

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '..')
const EN_RAW = resolve(ROOT, 'data/questions_raw.json')
const DE_RAW = resolve(ROOT, 'data/questions_raw_de.json')
const EN_ASSET = resolve(ROOT, 'assets/questions_en.json')
const OUT_ASSET = resolve(ROOT, 'assets/questions_de.json')
const OUT_SEED = resolve(ROOT, 'supabase/seed_de.sql')
const LANG = 'de'

function uuid(str) {
  const h = createHash('md5').update(str).digest('hex')
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`
}
const sq = (s) => "'" + String(s).replace(/'/g, "''") + "'"

const enRaw = JSON.parse(readFileSync(EN_RAW, 'utf8')).questions
const deRaw = JSON.parse(readFileSync(DE_RAW, 'utf8')).questions
const enAsset = JSON.parse(readFileSync(EN_ASSET, 'utf8'))

if (enRaw.length !== deRaw.length) {
  throw new Error(`EN (${enRaw.length}) und DE (${deRaw.length}) sind nicht gleich lang`)
}

// Lexikon EN-Antwort -> DE-Antwort (häufigste Variante) + präzise Paarung pro Frage
const variants = new Map() // enAnswer -> Map(deAnswer -> count)
const pair = new Map() // (enQ||enA) -> { q: deQ, a: deA }
for (let i = 0; i < enRaw.length; i++) {
  const ea = enRaw[i].a.trim()
  const da = deRaw[i].a.trim()
  if (!variants.has(ea)) variants.set(ea, new Map())
  const m = variants.get(ea)
  m.set(da, (m.get(da) || 0) + 1)
  pair.set(enRaw[i].q.trim() + '||' + ea, { q: deRaw[i].q.trim(), a: da })
}
const lex = new Map() // enAnswer -> häufigste DE-Antwort
for (const [ea, m] of variants) {
  let best = '',
    bestN = -1
  for (const [da, n] of m) if (n > bestN) (best = da), (bestN = n)
  lex.set(ea, best)
}

function trAnswer(en) {
  return lex.get(en.trim()) || en
}

// Pool deutscher Antworten für Ersatz-Ablenker bei Kollision
const dePool = [...new Set(lex.values())]

// Deutsches Asset (gleiche Struktur/Reihenfolge wie EN)
const deQuestions = enAsset.questions.map((q) => {
  const p = pair.get(q.question.trim() + '||' + q.answer.trim())
  const deAnswer = p ? p.a : trAnswer(q.answer)
  const dePrompt = p ? p.q : q.question
  const correctIdx = q.options.indexOf(q.answer)
  const out = q.options.map((o, idx) => (idx === correctIdx ? deAnswer : trAnswer(o)))

  // Dedup: doppelte Options-Texte ersetzen, korrekte Option geschützt
  const seen = new Set([deAnswer.toLowerCase()])
  let k = parseInt(uuid('dd:' + q.id).slice(0, 8), 16)
  for (let idx = 0; idx < out.length; idx++) {
    if (idx === correctIdx) continue
    if (seen.has(out[idx].toLowerCase())) {
      for (let t = 0; t < dePool.length; t++) {
        const cand = dePool[(k + t) % dePool.length]
        if (!seen.has(cand.toLowerCase())) {
          out[idx] = cand
          k += t + 1
          break
        }
      }
    }
    seen.add(out[idx].toLowerCase())
  }

  return {
    id: q.id,
    categories: q.categories,
    tags: q.tags,
    difficulty: q.difficulty,
    question: dePrompt,
    options: out,
    answer: deAnswer,
  }
})

mkdirSync(dirname(OUT_ASSET), { recursive: true })
writeFileSync(
  OUT_ASSET,
  JSON.stringify(
    { version: 2, lang: LANG, categories: enAsset.categories, questions: deQuestions },
    null,
    2,
  ),
)

// DB-Übersetzungen (verweisen auf bestehende Zeilen via deterministische UUIDs)
// Gebündelte Mehrzeilen-INSERTs (schnell & zuverlässig).
const CHUNK = 800
const qtr = []
const otr = []
for (const q of deQuestions) {
  const qid = uuid('q:' + q.id)
  qtr.push(`(${sq(qid)}, '${LANG}', ${sq(q.question)})`)
  q.options.forEach((opt, idx) => {
    const oid = uuid('opt:' + q.id + ':' + idx)
    otr.push(`(${sq(oid)}, '${LANG}', ${sq(opt)})`)
  })
}
function batch(table, cols, rows, conflict) {
  const out = []
  for (let i = 0; i < rows.length; i += CHUNK) {
    out.push(
      `insert into public.${table} (${cols}) values\n${rows.slice(i, i + CHUNK).join(',\n')}\non conflict ${conflict};`,
    )
  }
  return out
}
const lines = ['-- AUTO-GENERIERT (build_translations.mjs, batched) – DE-Übersetzungen.', 'begin;']
lines.push(
  ...batch('question_translations', 'question_id, lang, prompt', qtr,
    '(question_id, lang) do update set prompt=excluded.prompt'),
)
lines.push(
  ...batch('answer_option_translations', 'option_id, lang, text', otr,
    '(option_id, lang) do update set text=excluded.text'),
)
lines.push('commit;')
writeFileSync(OUT_SEED, lines.join('\n') + '\n')

// Wie viele Options-Texte blieben unübersetzt (= identisch zum EN, mit Buchstaben)?
let untranslated = 0
for (let i = 0; i < deQuestions.length; i++) {
  const en = enAsset.questions[i].options
  deQuestions[i].options.forEach((o, j) => {
    if (o === en[j] && /[A-Za-z]/.test(o)) untranslated++
  })
}
console.log(`✔ assets/questions_de.json (${deQuestions.length} Fragen)`)
console.log(`✔ supabase/seed_de.sql (${lines.length} Zeilen)`)
console.log(`Lexikon EN→DE: ${lex.size} Einträge | unübersetzte Options-Texte: ${untranslated} (von ${deQuestions.length * 4})`)
