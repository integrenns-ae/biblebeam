#!/usr/bin/env node
// Wandelt den rohen Fragenkatalog (data/questions_raw.json) in das Offline-
// Spiel-Asset um (Multiple-Choice, dedupliziert, kategorisiert).
// Ausgabe -> assets/questions_en.json
//
// Aufruf:  node scripts/build_questions.mjs

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { buildPack } from "./lib/transform.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const SRC = resolve(ROOT, "data/questions_raw.json");
const OUT = resolve(ROOT, "assets/questions_en.json");

const raw = JSON.parse(readFileSync(SRC, "utf8")).questions;
const pack = buildPack(raw);

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify(pack, null, 2));

console.log(`✔ ${pack.questions.length} Fragen geschrieben -> assets/questions_en.json`);
console.log("Kategorien:");
for (const c of pack.categories) console.log(`  ${c.slug.padEnd(12)} ${c.count}`);
