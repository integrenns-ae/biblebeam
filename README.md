# Lichtpfad – Bibelquiz

Cross-Platform Bibelquiz-App (Flutter) mit dem Visual-Konzept **„Lichtpfad"**.
Aktueller Stand: **Phase 1 MVP – Offline-Solo spielbar** (Englisch).

Vollständiger Plan: `~/.claude/plans/ich-plane-eine-bibelquiz-gleaming-kahn.md`

## Schnellstart

```bash
flutter pub get
flutter run -d chrome        # im Browser entwickeln (kein Xcode/Android nötig)
```

Weitere Geräte (später, nach Setup von Xcode / Android Studio):

```bash
flutter run -d ios           # iOS-Simulator
flutter run -d android       # Android-Emulator
```

## Fragenkatalog pflegen

Rohkatalog: `data/questions_raw.json` (EN) + `data/questions_raw_de.json` (DE),
Format `{ q, a, categories:[…], level }`. Index-gleich (Frage i ↔ Frage i).
Build-Schritte:

```bash
node scripts/build_questions.mjs      # EN  -> assets/questions_en.json
node scripts/build_translations.mjs   # DE  -> assets/questions_de.json + supabase/seed_de.sql
node scripts/build_seed.mjs           # DB-Seed (EN) -> supabase/seed.sql
```

Danach App neu starten/bauen, damit die aktualisierten Assets eingebunden werden.

- **Regionen**: aus Buch-Tags abgeleitet (8 Lichtpfad-Regionen), `scripts/lib/transform.mjs`.
- **Ablenker**: 3 falsche Optionen aus dem Antwort-Pool gleichen Typs (Person/Ort/Buch/Zahl/Vers).
- **Übersetzung**: korrekte Antwort exakt aus DE-Datei, Ablenker via Lexikon EN→DE; Dedup gegen Doppel-Optionen.
- **Schwierigkeit**: `level` easy/medium/hard → 1/2/3.
- Reproduzierbar dank festem Zufalls-Seed.

## Projektstruktur

```
lib/
  main.dart                     App-Einstieg
  theme/app_theme.dart          Lichtpfad-Palette, Typografie, Kategorie-Icons
  models/question.dart          Datenmodelle (Question / Category / Pack)
  data/question_repository.dart Asset-Loader (später: Supabase-Sync)
  services/                     Settings, Sound (SFX), Statistik (alle persistiert)
  widgets/starfield.dart        Nachthimmel-Hintergrund (CustomPainter)
  screens/
    home_screen.dart            Titel + Kategorie-Auswahl + Statistik
    quiz_screen.dart            Spielrunde (MC, Timer, Streak, Glow-Effekte, SFX)
    result_screen.dart          Ergebnis (Sternbild, Punkte, Vers)
    settings_screen.dart        Sound an/aus + Lautstärke
  l10n/strings.dart             UI-Übersetzungen de/ru/en
data/questions_raw.json         Roh-Fragenkatalog (Quelle)
assets/questions_en.json        generiertes Spiel-Asset
assets/sounds/*.wav             synthetisierte SFX
scripts/lib/transform.mjs       gemeinsame Transform-Logik (Asset + Seed)
scripts/build_questions.mjs     Transform Roh -> Offline-Asset
scripts/build_seed.mjs          Transform Roh -> supabase/seed.sql
scripts/build_sounds.mjs        Synthese der SFX-WAVs
supabase/migrations/            Postgres-Schema + RLS
admin/                          React/Vite Web-Admin (Phase 2) – siehe admin/README.md
```

## Roadmap (Kurzfassung)

0. ✅ **Katalog 3000** – 3000 Fragen (EN+DE), Schwierigkeit (easy/medium/hard), feine typgleiche Ablenker, mehrere Kategorien/Tags pro Frage (Testament/Buch/Typ), 8 Lichtpfad-Regionen abgeleitet
1. ✅ **Phase 1** – Offline-Solo MVP (Lichtpfad-Optik, Kategorien, MC, Timer, Streak, Ergebnis)
2. ✅ **Phase 1-Politur** – SFX (synthetisiert), Settings (Sound/Lautstärke, persistiert), Statistik-Persistenz
3. ✅ **Sprach-UI** – Umschaltung de/ru/en (UI), persistiert; Inhalt vorerst Englisch
4. 🟡 **Phase 2** – Supabase-Schema + Seed + React-Web-Admin **gebaut** (Frontend verifiziert); braucht noch ein Supabase-Projekt + Keys zum Live-Schalten → siehe `admin/README.md`
5. ⬜ App ↔ Supabase verbinden (Content-Pack-Sync), Ambient-Musik
6. ⬜ **Phase 3** – Online async Multiplayer (Auth E-Mail/Google/Apple, Matchmaking)
7. ⬜ **Phase 4** – WLAN-Multiplayer (mDNS + WebSocket-Host) für Hausgemeinschaften
8. ⬜ **Phase 5** – IAP 5 €-Unlock, Branding/Name, Store-Release

## Hinweise

- **Inhalt** startet Englisch-only; DE/RU werden später über mehrsprachige Strukturen ergänzt.
- **Branding/Name** („Lichtpfad" ist ein Arbeitstitel) noch offen.
- Web-Build cached aggressiv via Service-Worker; für cache-freie Vorschau:
  `flutter build web --pwa-strategy=none`.
