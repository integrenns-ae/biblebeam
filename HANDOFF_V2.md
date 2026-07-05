# Queezra — Handoff (V2)

Operatives Übergabe-Dokument für eine Session, die **deployen und Inhalte
importieren** kann. Enthält bewusst **KEINE Passwörter** (dieses Repo ist auf
GitHub öffentlich). Die nötigen Zugangsdaten nennt dir der Nutzer bzw. stehen im
privaten Handoff-Auftrag (Task-Chip), nicht hier.

## Projekt
- **Queezra** (früher „Lichtpfad") — Bibelquiz, Flutter-Web-**PWA**, live: https://bibelquiz.integrenns.de
- Untertitel/Marke: „Eine Lichtreise durch die Schrift" (bleibt; `tr('tagline')`, de/en/ru).
- Repo: `~/Projects/bibelquiz`. Git-Remote **origin = https://github.com/integrenns-ae/biblebeam (ÖFFENTLICH)**, Branches `main` + `v2` (aktive Linie), Tag `v2.0`.
- Backend: **Supabase** (Projekt-Ref `gwaxeojltvibqmfvweim`). DB = Single Source of Truth. **Stand: 6335 freigegebene Fragen** (Ziel des Nutzers: 10.000).

## Wichtige Nutzer-Vorgaben (Guardrails)
- **Fragen-Generierung NIE trimmen** — jede eindeutige, valide Frage behalten (nur Dubletten + Überschneidungen mit der DB filtern). Keine runden Zahlen.
- **Keine Passwörter in Dateien/Memory speichern** — nur inline im jeweiligen Befehl verwenden.
- Deutsch, knapp. Auto-Mode bevorzugt (zügig umsetzen, nicht endlos rückfragen).
- Vor destruktiven/öffentlichen Aktionen kurz absichern.

## Deploy (Web)
```bash
./scripts/deploy.sh   # baut + lädt hoch; fragt SFTP-Passwort interaktiv
```
Manuell (was das Skript tut):
1. `flutter build web --wasm --pwa-strategy=none`  (skwasm; Flutters eingebauter SW ist deprecated)
2. SW-Cache stempeln, damit neue Deploys sauber greifen:
   `STAMP="$(date +%Y%m%d%H%M%S)"; sed -i '' "s/const CACHE = '[^']*';/const CACHE = 'queezra-$STAMP';/" build/web/sw.js`
3. Upload nach STRATO via **lftp/SFTP**:
   - Host `59543682.ssh.w1.strato.hosting`, User `stu152339249`, Port 22, SFTP, chroot = Subdomain-Docroot.
   - `lftp -u "$USER,$PW" "sftp://$HOST" -e "set sftp:auto-confirm yes; mirror -R --delete build/web /; bye"`
- Verifikation: `curl -s -o /dev/null -w '%{http_code}' https://bibelquiz.integrenns.de/` → 200.
- **SW-Verhalten:** stale-while-revalidate + Cache-Stempel je Deploy + `controllerchange`→einmaliger Reload in `web/index.html` → neuer Deploy wird beim nächsten Laden automatisch übernommen (sonst Cmd+Shift+R).

## Inhalte importieren / Assets bauen
- **DB-Verbindung:** `host=db.gwaxeojltvibqmfvweim.supabase.co port=5432 user=postgres dbname=postgres sslmode=require` (Passwort inline via `PGPASSWORD`).
- Neue Fragen einspielen: eine `supabase/seed_*.sql` (aus einem `scripts/build_import_*.mjs` erzeugt) mit `psql -f` anwenden (Fragen `on conflict do nothing`, `status='approved'`).
- Assets aus der DB neu erzeugen: `./scripts/refresh-assets.sh` (psql-Dump inkl. `explanations` + `node scripts/build_assets_from_db.mjs`) → `assets/questions_{de,en}.json`.
- Danach: committen → `./scripts/deploy.sh`.
- **PostgREST-Cache** nach neuem RPC neu laden: `notify pgrst, 'reload schema';` (sonst PGRST202).

## Datenmodell (Kurz)
- Fragen: `questions(status,difficulty,source)`, `question_translations(lang,prompt,explanation)`, `answer_options(is_correct,sort)`, `answer_option_translations(lang,text)`, `question_categories` n:m `categories(slug,kind)`.
- **Bibelstelle** einer Frage = `question_translations.explanation` (pro Sprache). Wird bei der Auflösung angezeigt (Solo + Hotseat). Optional (`Question.reference`).
- Roh-Formate: `data/questions_raw*.json` (einsprachig, `{q,a,categories,level}`), `data/questions_raw_v2_phrases.json` + `data/questions_hard_v3.json` (zweisprachig `q_de/q_en`, `options_de/options_en`, `answer_index`, optional `ref_de/ref_en`).
- Importer: `scripts/build_import_v2.mjs` (v2-Phrasen), `scripts/build_import_v3.mjs` (schwere + Referenzen). Kategorie-UUIDs = `uuid('cat:'+slug)` == DB-IDs (geprüft, kein FK-Risiko).
- Regionen (Home-Karten) werden aus Buch-Tags abgeleitet; Zähler summieren sich exakt = Gesamtzahl (jede Frage genau 1 Region).

## Fragen-Generierung (bewährtes Muster)
- Pro Bibel-Territorium ein Agent → JSON-Array in den Scratchpad; dann mergen, gegen die bestehende DB deduplizieren, **NICHT trimmen**, Importer + Import.
- Referenzen (Bibelstellen) separat per Agent nachziehen (Genauigkeit hat Vorrang, im Zweifel leer).

## Supabase Keepalive (WICHTIG)
- Free-Tier **pausiert nach 7 Tagen ohne API-Aktivität** (Host NXDOMAIN). Reaktivieren nur via Dashboard („Restore"). Daten 90 Tage sicher.
- Gegenmittel: `scripts/keepalive.sh` (täglicher Cron-Ping) — soll auf dem kol316-Hetzner-Server laufen (User-Aufgabe). App läuft derweil über gebündeltes Asset weiter.

## iOS (separater Track, via Cowork)
- `ios/` vorhanden. Name **Queezra**, Bundle-ID **de.integrenns.queezra**. App-Icon aus `assets/icons/app_icon_1024.png` (`flutter_launcher_icons`).
- Anleitung: `IOS_SETUP_COWORK.md`. Entscheidung: erst auf eigenem iPhone testen (kostenlose Apple-ID, 7-Tage-Signatur), Developer-Programm (99 $/Jahr) später.
- Braucht Xcode (nicht installiert; Speicher knapp) + CocoaPods.

## Web-Optik (nur Web)
- `web/nebula.js`: WebGL-Nebel (fBm + Domain-Warping) + DOM-Sterne, hinter der im Web transparenten Flutter-App (`kIsWeb` → Starfield/Scaffold transparent). Nativ bleibt der Flutter-Starfield. `nebula.js` ist statisches Asset → `cp web/nebula.js build/web/` + Reload zum Iterieren.

## Sicherheits-Follow-up (offen)
- Reviewer-Admin-Creds stehen in `lib/config.dart` (Klartext) und damit im öffentlichen Repo + Web-Build. Task task_3da53bfd: Konto sichern / Review-Schreibzugriff serverseitig lösen.

## Benötigte Zugangsdaten (NICHT hier gespeichert)
- **Supabase DB-Passwort** (User postgres) — für Import/Assets.
- **STRATO SFTP-Passwort** (User stu152339249) — für Deploy.
- Git-Push: läuft über den vorhandenen Credential-Helper (kein `gh` installiert).
Diese liefert der Nutzer der ausführenden Session direkt (bewusst nirgends persistiert).
