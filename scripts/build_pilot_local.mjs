#!/usr/bin/env node
// NUR FÜR PILOT-PREVIEW (kein DB-Zugriff): führt data/questions_bibel_v4.json
// lokal in die Assets zusammen, damit man die neue Kategorie + RU in der App
// ansehen kann, OHNE die Produktions-DB anzufassen.
//   - questions_en/de.json: bestehender Katalog + Pilot (en/de)
//   - questions_ru.json:    bestehender Katalog als EN-Fallback + Pilot (ru)
// Der echte Deploy läuft später über build_import_v4 -> psql -> refresh-assets
// (DB = Single Source of Truth); diese Datei ist ein temporäres Preview-Werkzeug.
//
// Aufruf: node scripts/build_pilot_local.mjs

import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const LEVEL = { easy: 1, medium: 2, hard: 3 }
const md5 = (s) => createHash('md5').update(s).digest('hex')
const uuid = (s) => {
  const h = md5(s)
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`
}
const readJson = (p) => JSON.parse(readFileSync(resolve(ROOT, p), 'utf8'))

const baseEn = readJson('assets/questions_en.json')
const baseDe = readJson('assets/questions_de.json')
const parsed = readJson('data/questions_bibel_v4.json')
const pilot = Array.isArray(parsed) ? parsed : parsed.questions

const mk = (it, i, lang) => {
  const id = uuid('q:v4b-' + String(i + 1).padStart(4, '0'))
  const options = it['options_' + lang]
  return {
    id,
    categories: ['bibel'],
    difficulty: LEVEL[it.level] || 2,
    question: it['q_' + lang].trim(),
    options: options.map((o) => String(o).trim()),
    answer: String(options[it.answer_index]).trim(),
  }
}

const pilotEn = pilot.map((it, i) => mk(it, i, 'en'))
const pilotDe = pilot.map((it, i) => mk(it, i, 'de'))
const pilotRu = pilot.map((it, i) => mk(it, i, 'ru'))

const bibelCat = { slug: 'bibel', name: 'About the Bible', count: pilot.length }
const withBibel = (cats) => [bibelCat, ...cats.filter((c) => c.slug !== 'bibel')]

const packs = {
  'assets/questions_en.json': {
    version: 2, lang: 'en',
    categories: withBibel(baseEn.categories),
    questions: [...baseEn.questions, ...pilotEn],
  },
  'assets/questions_de.json': {
    version: 2, lang: 'de',
    categories: withBibel(baseDe.categories),
    questions: [...baseDe.questions, ...pilotDe],
  },
  // RU = ganzer Katalog auf Englisch (Fallback) + Pilot auf Russisch
  'assets/questions_ru.json': {
    version: 2, lang: 'ru',
    categories: withBibel(baseEn.categories),
    questions: [...baseEn.questions, ...pilotRu],
  },
}

for (const [path, pack] of Object.entries(packs)) {
  writeFileSync(resolve(ROOT, path), JSON.stringify(pack, null, 2))
  console.log(`✔ ${path}: ${pack.questions.length} Fragen (${pilot.length} Bibel-Pilot), ${pack.categories.length} Kategorien`)
}
