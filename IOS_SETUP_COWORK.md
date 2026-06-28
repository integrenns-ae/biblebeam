# Auftrag an Claude Cowork: iOS-Entwicklung für „Lichtpfad" einrichten

Du richtest die iOS-Entwicklungsumgebung für die Flutter-App **Lichtpfad** (Bibelquiz)
ein und bringst sie zum ersten Mal auf einem iPhone/Simulator zum Laufen. Ziel ist der
Weg Richtung **App-Store-Launch**. Arbeite die Schritte der Reihe nach ab, **verifiziere
nach jedem Schritt** und brich bei Fehlern ab, statt blind weiterzumachen.

---

## Projekt-Kontext (alles bereits vorhanden)

- **Repo:** `~/Projects/bibelquiz` (Flutter, Dart). Aktiver Branch: `v2`.
- **App:** „Lichtpfad", ein Bibelquiz. Läuft schon als PWA unter https://bibelquiz.integrenns.de.
- **Backend:** Supabase (Config liegt fertig in `lib/config.dart`, anon-Key ist öffentlich, nichts einzurichten).
- **Plattform-Ordner `ios/` und `android/` existieren bereits** (Flutter hat sie angelegt).
- **App-Icon-Quelle:** `web/icons/icon-source.svg` (Lichtpfad-Motiv). Farben: Nachtblau `#0E1330`, Gold `#E7B85C`, Creme `#F4ECDD`.
- Build-Befehle der Web-App (NICHT für iOS nötig, nur zur Info): `flutter build web --wasm --pwa-strategy=none`.

## Umgebung (vorab geprüft – nicht neu raten)

- macOS 15.7.7, **Intel-Mac** (darwin-x64) → iOS-Simulator ok, aber langsamer als auf Apple Silicon.
- Flutter **3.44.1 stable** ✓ installiert.
- **Xcode: NICHT installiert** (nur Command-Line-Tools). CocoaPods: **nicht installiert**.
- Homebrew ✓ vorhanden. System-Ruby ist 2.6 (deshalb CocoaPods über Homebrew, nicht über `gem`).
- Freier Speicher: ~**53 GB** → für Xcode **zu knapp**, siehe Schritt 0.

---

## Schritt 0 — Speicher prüfen (BLOCKER)

```bash
df -g / | tail -1 | awk '{print $4" GB frei"}'
```
Xcode braucht ~15 GB Download + transient ~30–40 GB beim Auspacken + Simulatoren (~7 GB/Version).
**Wenn < 70 GB frei:** dem Nutzer melden, dass er aufräumen muss (Papierkorb leeren, alte
Downloads/Caches), und hier stoppen. Nicht mit knappem Speicher weitermachen.

## Schritt 1 — Xcode installieren (braucht den Nutzer)

Xcode kommt aus dem **Mac App Store** und erfordert eine Apple-ID-Anmeldung → das kann ein
Agent i. d. R. nicht autonom. Vorgehen:
1. Prüfe, ob Xcode schon da ist: `ls -d /Applications/Xcode.app 2>/dev/null && echo DA || echo FEHLT`.
2. Falls FEHLT: Optional `brew install mas` und `mas install 497799835` (Xcode) versuchen —
   das klappt nur, wenn der Nutzer im App Store angemeldet ist. Sonst den Nutzer bitten,
   Xcode manuell aus dem App Store zu laden, und **warten/stoppen**, bis es installiert ist.

## Schritt 2 — Xcode-Kommandozeile aktivieren (Agent)

Sobald `/Applications/Xcode.app` existiert:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license accept
```
(`sudo` braucht das Nutzer-Passwort — ggf. den Nutzer eingeben lassen.)

## Schritt 3 — CocoaPods installieren (Agent)

```bash
brew install cocoapods
pod --version
```

## Schritt 4 — Toolchain verifizieren

```bash
flutter doctor -v
```
Erwartung: **Xcode jetzt ✓**, CocoaPods ✓. Falls noch ✗, die genannten Hinweise abarbeiten.

## Schritt 5 — App-Identität setzen (Agent, im Repo)

- **Bundle Identifier** von Standard (`com.example.*`) auf etwas Eigenes ändern, Vorschlag
  `de.integrenns.lichtpfad`. Am einfachsten über Xcode (Runner → Signing & Capabilities) oder
  per `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`). Danach `flutter build` testen.
- **Anzeigename** „Lichtpfad" prüfen (`ios/Runner/Info.plist` → `CFBundleDisplayName`).
- **App-Icon** aus `web/icons/icon-source.svg` erzeugen: SVG → 1024×1024 PNG rendern und die
  iOS-Icon-Sätze füllen. Empfohlen: Paket `flutter_launcher_icons` als dev_dependency, in
  `pubspec.yaml` konfigurieren (`image_path`, `ios: true`), dann `dart run flutter_launcher_icons`.

## Schritt 6 — Erster Start

- Simulator: `open -a Simulator` dann `flutter devices`, danach `flutter run -d "<simulator-id>"`.
- Echtes iPhone (per Kabel, „diesem Computer vertrauen"): `flutter devices`, `flutter run -d "<iphone-id>"`.
  Beim ersten Mal in Xcode ein **Signing-Team** wählen (Apple-ID des Nutzers; kostenlose ID
  reicht zum Testen, Signatur läuft nach 7 Tagen ab).
- Eine komplette Solo-Quizrunde durchspielen; auf Renderfehler/Plugin-Fehler achten
  (supabase_flutter, shared_preferences laufen via CocoaPods).

## Schritt 7 — Bericht an den Nutzer

Fasse zusammen: Was installiert/geändert wurde, ob die App auf Simulator und/oder iPhone
lief, und die **offenen Entscheidungen**:
- **Apple Developer Program (99 $/Jahr)** — nötig für TestFlight (Familie/Gemeinde testet
  drahtlos) und App-Store-Release. Ohne: nur eigenes Testen mit kostenloser Apple-ID (7-Tage-Signatur).
- **In-App-Kauf 5 € (Unlock):** Paket `in_app_purchase` ist noch NICHT im `pubspec.yaml`;
  Einbau + App-Store-Connect-Produkt sind ein eigener späterer Schritt.

---

## Wichtige Leitplanken

- **Nichts an `lib/config.dart`, Supabase oder dem Web-Deploy ändern** — das läuft produktiv.
- Keine Passwörter in Dateien speichern.
- Bei `sudo`/App-Store-/Apple-ID-Schritten den Nutzer einbeziehen statt zu raten.
- Auf dem Intel-Mac den Speicher im Auge behalten (Simulator-Runtimes sind groß).
- Branch `v2` verwenden; sinnvolle, kleine Commits mit klaren Nachrichten.
