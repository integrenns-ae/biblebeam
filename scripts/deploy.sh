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

echo "==> Assets neu bauen (questions, seed, übersetzungen)"
node scripts/build_questions.mjs >/dev/null
node scripts/build_translations.mjs >/dev/null

echo "==> Flutter-Web-Build (ohne Service-Worker, einfacheres Cache-Verhalten)"
flutter build web --pwa-strategy=none

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
