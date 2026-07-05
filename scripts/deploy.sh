#!/usr/bin/env bash
# Deployt die Flutter-Web-App auf STRATO (https://bibelquiz.integrenns.de) via SFTP.
# Baut die App und spiegelt build/web in den Subdomain-Ordner.
# Das SFTP-Passwort wird interaktiv abgefragt und NICHT gespeichert.
#
# Aufruf:  ./scripts/deploy.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

HOST="59543682.ssh.w1.strato.hosting"
USER="stu152339249"

# HINWEIS: Die Assets (assets/questions_*.json) sind ab 2026-06-11 die
# AUS DER SUPABASE-DB generierte Variante (Single Source of Truth) – sie
# enthalten Admin-Edits + Grammatik-Korrekturen, die NICHT im Roh-Katalog
# data/questions_raw.json stehen. Deshalb hier KEIN build_questions/
# build_translations mehr (würde die Korrekturen überschreiben).
# Inhalte aktualisieren -> scripts/refresh-assets.sh (zieht frisch aus der DB).

echo "==> Flutter-Web-Build (WASM-Renderer; eigener sw.js statt Flutters deprecated SW)"
flutter build web --wasm --pwa-strategy=none

# SW-Cache pro Deploy stempeln -> neuer Deploy verwirft den alten Cache,
# Code-Assets (main.dart.wasm etc.) werden frisch geladen statt stale serviert.
STAMP="$(date +%Y%m%d%H%M%S)"
sed -i '' "s/const CACHE = '[^']*';/const CACHE = 'queezra-$STAMP';/" build/web/sw.js
echo "==> SW-Cache-Version: queezra-$STAMP"

read -r -s -p "SFTP-Passwort für $USER: " PW
echo

echo "==> Upload nach https://bibelquiz.integrenns.de"
lftp -u "$USER,$PW" "sftp://$HOST" -e "
  set sftp:auto-confirm yes;
  set mirror:parallel-transfer-count 5;
  set net:timeout 30;
  mirror -R --delete --verbose=1 build/web /;
  bye
"

echo "✔ Fertig -> https://bibelquiz.integrenns.de"
