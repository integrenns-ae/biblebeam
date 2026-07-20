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

## LAUFENDE AUFGABE (2026-07-17): Kategorie „Bibel" — dreisprachig, Ziel 1000 Fragen
**Ziel:** Neue Quiz-Kategorie mit Fakten ÜBER die Bibel als Buch (Aufbau, Kanon,
Statistik, Übersetzungsgeschichte) — NICHT biblische Inhalte/Geschichten. 1000
Fragen, alle in de/en/ru.

**STATUS: Integration fertig + committet. Pilot (78 Fragen) gebaut, im lokalen
Preview verifiziert (de/en/ru), korrekt eingestuft. NOCH NICHT in der DB, NICHT
deployed.**

**Was eingebaut ist (committet):**
- **Neue Kategorie „bibel"** als eigene Region (nicht aus Buch-Tag abgeleitet):
  Region-Slug in `scripts/build_assets_from_db.mjs` (REGIONS + `if (c.slug==='bibel')`)
  und `lib/data/content_sync.dart` (`_regions` + slug-Sonderfall); Icon/Farbe in
  `lib/theme/app_theme.dart` (`CategoryStyle 'bibel'`); Name `cat.bibel` (de/en/ru)
  in `lib/l10n/strings.dart`. Fragen tragen den Tag `["bibel"]` (kind=type), der
  Importer legt die DB-Kategorie automatisch an.
- **Russisch als Inhaltssprache aktiviert** (mit EN-Fallback für den restlichen
  Katalog): `question_repository.dart` `_available={'en','de','ru'}`;
  `build_assets_from_db.mjs` baut jetzt auch `ru` mit `pick()`-Fallback auf `en`;
  `pubspec.yaml` registriert `assets/questions_ru.json`. **`questions_ru.json` ist
  aktuell nur ein Bootstrap (EN-Kopie)** — `refresh-assets.sh` regeneriert es echt
  aus der DB (dann RU wo vorhanden, sonst EN).
- **Importer `scripts/build_import_v4.mjs`** (Kopie von v3): dreisprachig
  (de/en/ru), ID-Präfix `v4b-`, source `bibel-v4`, Tag „bibel", CAT_NAMES für
  de/en/ru. Liest `data/questions_bibel_v4.json` (Array). `on conflict do nothing`.
- **Pilot-Daten:** `data/questions_bibel_v4.json` (78 Fragen, korrekt eingestuft
  31 leicht / 17 mittel / 30 schwer). `scripts/build_pilot_local.mjs` = temporäres
  Preview-Werkzeug (merged Pilot lokal in Assets OHNE DB — nur zum Ansehen).

**Entscheidungen/Guardrails (Nutzer bestätigt):**
- Protestantischer 66-Bücher-Kanon als Basis; Kanon-/Anzahl-/Reihenfolge-Fragen
  mit „protestantischer Kanon" qualifiziert.
- **Синодальный-Fallen vermeiden:** Kapitelzahlen kanon-abhängig! Daniel (12 prot.
  vs 14 orthodox) + „Buch vor Römer" (orthodox = Judas, nicht Apg) wurden aus dem
  Pilot ENTFERNT. Psalmennummerierung im RU als „Псалом 118 (119)" behandeln.
  Nachbar-Fragen nur in tradiitions­übergreifend gleichen Zonen (Pentateuch, kleine
  Propheten, Evangelien).
- Übersetzungszahl „~700 Sprachen (vollständige Bibel, 2020er)"; Verse „~31.000".
- Autorschaften nur unstrittig; strittige (Hebräer/Prediger/Hiob/2.Petrus/Psalmen)
  ausgelassen, Evangelien/Offb/Apg nur „traditionell zugeschrieben".

**RUBRIK (fest einbauen, Nutzer bestätigt):** leicht=Allgemeinwissen (Bücherzahlen,
erstes/letztes Buch, Testament, unstrittige Paulus-Briefe, Luther/Gutenberg);
mittel=Bibelkenntnis/Trivia (Nachbarbuch, 12 kleine Propheten, längstes/kürzestes
Kapitel, Septuaginta, Pentateuch-Begriff, Psalmenzahl 150); schwer=exakte
Zahlen/Daten (Kapitelzahlen einzelner Bücher, Gesamtverse, längster Vers,
Sprach-/Autorenzahl, KJV 1611, Vulgata/Hieronymus).
**ZIEL-VERTEILUNG der 1000: 30 % leicht / 35 % mittel / 35 % schwer** — über den
Themen-Mix steuern (nicht von Kapitelzahlen dominieren lassen; „mittel" braucht
Volumen an Reihenfolge-/Struktur-/Trivia-Fragen).

**ARBEITSTEILUNG (vom Nutzer so gewünscht):**
- **NEUE Session = NUR Generierung.** Erzeugt die 1000 Fragen und committet/pusht
  die Datei. **KEIN DB-Import, KEIN Deploy, KEINE Passwörter** — das übernimmt eine
  separate Deploy-Session. (Der Nutzer will NICHT, dass die generierende Session
  ums Deployen „kämpft".)
- **Deploy-Session (separat) = DB + Live.** Zieht die fertige Datei, importiert,
  baut Assets, deployt.

**Schritt 1 — NEUE Session (nur das!):** 1000 Fragen generieren — Multi-Agent-
Workflow (token-intensiv, Nutzer hat eingewilligt): systematisch über Themenfelder
fächern, nach Rubrik auf 30/35/35 einstufen, dreisprachig index-gleich,
Синодальный-Guardrails, **adversarial faktengeprüft** (falsche Zahlen abfangen),
dedupliziert (untereinander + gegen die bestehenden ~6335). Ausgabe →
`data/questions_bibel_v4.json` (ersetzt/erweitert den Pilot), dann committen +
pushen. Guardrail: NICHT trimmen, keine runden Zahlen. **DANACH STOPP** — dem
Nutzer melden, dass die Datei fertig + gepusht ist. NICHT weiter zu DB/Deploy.

**Schritte 2–5 — Deploy-Session (NICHT die generierende Session):**
2. `git pull` (falls nötig); `node scripts/build_import_v4.mjs` → `supabase/seed_bibel_v4.sql`
3. `psql "<conn>" -v ON_ERROR_STOP=1 -f supabase/seed_bibel_v4.sql` (DB-PW aus `~/.pgpass`)
4. `./scripts/refresh-assets.sh` (baut `questions_{en,de,ru}.json` echt aus der DB)
5. commit + Deploy (netrc). Verifizieren: Kategorie „Über die Bibel/О Библии" im
   Grid, RU-Frage spielbar.
- **`~/.pgpass` einrichten** (einmalig, analog netrc; psql liest es selbst):
  ```bash
  umask 077
  read -r -s -p "Supabase DB-Passwort: " PW && printf 'db.gwaxeojltvibqmfvweim.supabase.co:5432:postgres:postgres:%s\n' "$PW" >> ~/.pgpass && chmod 600 ~/.pgpass && unset PW && echo " ✓"
  ```
- Kleinigkeit: Settings-Text „Questions are currently in English" (strings.dart) ist
  nach RU-Aktivierung veraltet → anpassen.

## Spielmodi & neueste Features (Stand 2026-07-16)
- **Solo / Quick Play** (`lib/screens/quiz_screen.dart`): 10 Fragen, Komet-Timer.
  **Zeit pro Frage jetzt schwierigkeitsabhängig** (`_secondsFor`): schwer 20 s, mittel
  25 s, leicht 30 s — pro Frage bemessen (wirkt auch im „Alle"-Filter).
- **Endlos / Survival** (NEU; `survival_screen.dart` + `survival_result_screen.dart`,
  Home-Button „∞ Endless"): 3 Leben (falsch/Timeout = −1), unbegrenzte Fragen,
  Zeitdruck steigt (alle 5 richtigen −1 s, Boden 8 s), Highscore
  `StatsService.survivalBest`. `recordSurvival` aktualisiert nur totalCorrect/
  totalQuestions + survivalBest (nicht gamesPlayed/bestScore). Hängt bewusst NOCH
  NICHT am Achievement-System (offener Follow-up: „Survivor"-Achievement).
- **Aufsteigender Streak-Sound** (beide Modi): `SoundService.playCorrect(streak:)`
  hebt die Tonhöhe je Serie via `setPlaybackRate` (1.0…~1.48, gedeckelt).
- **Geteilte Widgets:** Komet-Timer (`lib/widgets/comet_painter.dart`) + Antwort-Kachel
  (`lib/widgets/answer_tile.dart`) — quiz + survival teilen dieselbe Optik/„Juice".
- **2-Spieler-Hotseat** (`hotseat_*`) unverändert. Alle Modi Solo-only fürs
  Achievement-/Stats-System außer wo vermerkt.
- Commit ab5ee1e auf `v2`, live deployed + verifiziert.

## Wichtige Nutzer-Vorgaben (Guardrails)
- **Fragen-Generierung NIE trimmen** — jede eindeutige, valide Frage behalten (nur Dubletten + Überschneidungen mit der DB filtern). Keine runden Zahlen.
- **Keine Passwörter in Dateien/Memory speichern** — nur inline im jeweiligen Befehl verwenden.
- Deutsch, knapp. Auto-Mode bevorzugt (zügig umsetzen, nicht endlos rückfragen).
- Vor destruktiven/öffentlichen Aktionen kurz absichern.

## Deploy (Web) — AUTONOM via ~/.netrc
Die ausführende Session kann **selbst deployen, ohne ein Passwort anzufassen**: Das
SFTP-Passwort liegt lokal in **`~/.netrc`** (`machine 59543682.ssh.w1.strato.hosting
login stu152339249 password …`, chmod 600, OFF-Repo). `lftp` holt es sich von dort —
wie Gits Credential-Helper beim Push. Also: **kein `-u "user,$PW"` im Befehl.**

Ablauf (das macht `deploy.sh` inhaltlich — aber sein interaktives `read -s`
funktioniert NICHT non-interaktiv, deshalb die Schritte direkt fahren):
1. `flutter build web --wasm --pwa-strategy=none`  (skwasm; Flutters eingebauter SW ist deprecated)
2. SW-Cache stempeln, damit neue Deploys sauber greifen:
   `STAMP="$(date +%Y%m%d%H%M%S)"; sed -i '' "s/const CACHE = '[^']*';/const CACHE = 'queezra-$STAMP';/" build/web/sw.js`
3. Upload nach STRATO via **lftp/SFTP** (Passwort kommt aus netrc):
   `lftp "sftp://stu152339249@59543682.ssh.w1.strato.hosting" -e "set sftp:auto-confirm yes; set mirror:parallel-transfer-count 5; mirror -R --delete build/web /; bye"`
   - Host chroot = Subdomain-Docroot (`/htdocs/bibelquiz`), base href `/` passt.
- Verifikation: `curl -s -o /dev/null -w '%{http_code}' https://bibelquiz.integrenns.de/` → 200; Live-SW-Stempel prüfen: `curl -s https://bibelquiz.integrenns.de/sw.js | grep CACHE` == der eben gestempelte.
- **SW-Verhalten:** stale-while-revalidate + Cache-Stempel je Deploy + `controllerchange`→einmaliger Reload in `web/index.html` → neuer Deploy wird beim nächsten Laden automatisch übernommen (sonst Cmd+Shift+R).
- **GRENZE (gilt weiter):** Klartext-Passwort NIE inline in einen Befehl bauen — auch nicht aus einer gesourceten `deploy.env`/`$STRATO_SFTP_PASSWORD`. Nur Tool-eigene Credential-Stores (netrc / git-helper / `~/.pgpass` fürs DB-PW). Falls netrc mal fehlt/rotiert wurde und der Upload scheitert: NICHT das PW inline eintragen, sondern den Nutzer die eine netrc-Zeile aktualisieren lassen.

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

## Zugangsdaten
- **STRATO SFTP (Deploy):** liegt in **`~/.netrc`** → Deploy läuft autonom, kein PW
  nötig (siehe Deploy-Sektion). Falls die netrc-Zeile fehlt (frische Maschine),
  legt der Nutzer sie einmalig an; NIE das PW inline in Befehle bauen.
- **Supabase DB-Passwort** (User postgres) — für Import/Assets. Noch NICHT in einem
  Store; ideal wäre `~/.pgpass` (liest psql selbst, analog netrc). Bis dahin nennt es
  der Nutzer bei Bedarf; NIE persistieren/inline hartkodieren.
- **Git-Push:** läuft über den vorhandenen Credential-Helper (kein `gh` installiert).
- **Hinweis:** DB- + SFTP-Passwort wurden am 2026-07-16 im Chat offengelegt → Nutzer
  rotiert sie; danach netrc (SFTP) bzw. pgpass/Befehl (DB) mit neuem PW nachziehen.
