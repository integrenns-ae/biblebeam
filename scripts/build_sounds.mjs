#!/usr/bin/env node
// Synthetisiert würdevolle SFX (Harfe/Glocke) als 16-bit-PCM-WAV.
// Kein Arcade-Buzzer – warm & weich. Ausgabe -> assets/sounds/*.wav
//
// Aufruf:  node scripts/build_sounds.mjs

import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUTDIR = resolve(__dirname, "../assets/sounds");
const SR = 44100;

// Note -> Frequenz
const N = {
  F3: 174.61, A3: 220.0, C4: 261.63, E4: 329.63, G4: 392.0,
  C5: 523.25, D5: 587.33, E5: 659.25, G5: 783.99, C6: 1046.5,
};

// Ein glockenartiger Ton: Grundton + leise Obertöne, exponentielles Decay.
function tone(freq, dur, { gain = 0.5, decay = 6, harmonics = [1, 0.5, 0.25] } = {}) {
  const len = Math.floor(SR * dur);
  const buf = new Float32Array(len);
  for (let i = 0; i < len; i++) {
    const t = i / SR;
    const env = Math.exp(-decay * t);
    let s = 0;
    harmonics.forEach((amp, h) => {
      s += amp * Math.sin(2 * Math.PI * freq * (h + 1) * t);
    });
    buf[i] = s * env * gain;
  }
  return buf;
}

// mische mehrere Buffer mit Start-Offsets (Sekunden) in eine Spur
function mix(parts, totalDur) {
  const len = Math.floor(SR * totalDur);
  const out = new Float32Array(len);
  for (const { buf, at } of parts) {
    const off = Math.floor(SR * at);
    for (let i = 0; i < buf.length && off + i < len; i++) out[off + i] += buf[i];
  }
  // sanftes Fade-out am Ende gegen Klicks
  const fade = Math.floor(SR * 0.02);
  for (let i = 0; i < fade; i++) out[len - 1 - i] *= i / fade;
  // Normalisieren / Clipping vermeiden
  let peak = 0;
  for (const v of out) peak = Math.max(peak, Math.abs(v));
  if (peak > 0.98) for (let i = 0; i < len; i++) out[i] = (out[i] / peak) * 0.98;
  return out;
}

function arpeggio(notes, { step = 0.09, dur = 0.5, gain = 0.5, decay = 6 } = {}) {
  const total = step * notes.length + dur;
  const parts = notes.map((f, i) => ({
    buf: tone(f, dur, { gain, decay }),
    at: i * step,
  }));
  return mix(parts, total);
}

function toWav(float32) {
  const len = float32.length;
  const buf = Buffer.alloc(44 + len * 2);
  buf.write("RIFF", 0);
  buf.writeUInt32LE(36 + len * 2, 4);
  buf.write("WAVE", 8);
  buf.write("fmt ", 12);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20); // PCM
  buf.writeUInt16LE(1, 22); // mono
  buf.writeUInt32LE(SR, 24);
  buf.writeUInt32LE(SR * 2, 28);
  buf.writeUInt16LE(2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write("data", 36);
  buf.writeUInt32LE(len * 2, 40);
  for (let i = 0; i < len; i++) {
    let s = Math.max(-1, Math.min(1, float32[i]));
    buf.writeInt16LE((s * 32767) | 0, 44 + i * 2);
  }
  return buf;
}

mkdirSync(OUTDIR, { recursive: true });

const sounds = {
  // richtig: helles aufsteigendes Dreiklang-Arpeggio (entzündetes Licht)
  correct: arpeggio([N.C5, N.E5, N.G5], { step: 0.085, dur: 0.55, gain: 0.42, decay: 5.5 }),
  // falsch: zwei weiche tiefe Töne, sanft – nicht bestrafend
  wrong: mix(
    [
      { buf: tone(N.A3, 0.45, { gain: 0.32, decay: 7, harmonics: [1, 0.3] }), at: 0 },
      { buf: tone(N.F3, 0.5, { gain: 0.3, decay: 7, harmonics: [1, 0.3] }), at: 0.12 },
    ],
    0.65
  ),
  // tap: kurzer weicher Blip
  tap: tone(N.E5, 0.09, { gain: 0.25, decay: 18, harmonics: [1] }),
  // finish: volleres aufsteigendes Arpeggio (Sternbild vollendet)
  finish: arpeggio([N.C5, N.E5, N.G5, N.C6], { step: 0.11, dur: 0.7, gain: 0.4, decay: 4 }),
};

for (const [name, data] of Object.entries(sounds)) {
  const out = resolve(OUTDIR, `${name}.wav`);
  writeFileSync(out, toWav(data));
  console.log(`✔ ${name}.wav (${(data.length / SR).toFixed(2)}s)`);
}
