#!/usr/bin/env node
// Exportiert die DEUTSCHEN Fragen MIT stabiler ID und Antwortoptionen,
// in derselben Struktur wie data/questions_export_with_ids.json (EN).
// Ausgabe -> data/questions_export_with_ids_de.json
//   { id, q, options:[4], answerIndex, categories, level }   (Texte Deutsch)
//
// Aufruf:  node scripts/build_questions.mjs && node scripts/build_translations.mjs && node scripts/build_export_de.mjs

import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const ROOT = resolve(__dirname, '..')
const ASSET = resolve(ROOT, 'assets/questions_de.json')
const OUT = resolve(ROOT, 'data/questions_export_with_ids_de.json')

const LEVEL = { 1: 'easy', 2: 'medium', 3: 'hard' }
const asset = JSON.parse(readFileSync(ASSET, 'utf8')).questions

const out = asset.map((q) => ({
  id: q.id,
  q: q.question,
  options: q.options,
  answerIndex: q.options.indexOf(q.answer),
  categories: q.tags,
  level: LEVEL[q.difficulty] || 'medium',
}))

const bad = out.filter((q) => q.answerIndex < 0).length
writeFileSync(OUT, JSON.stringify({ questions: out }, null, 2))
console.log(`✔ ${out.length} Fragen (DE, mit Optionen) -> data/questions_export_with_ids_de.json`)
if (bad) console.log(`⚠ ${bad} Fragen ohne gültigen answerIndex – prüfen`)
