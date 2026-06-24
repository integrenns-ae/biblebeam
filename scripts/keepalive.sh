#!/usr/bin/env bash
# Keepalive für das Supabase-Free-Tier-Projekt (bibelquiz / gwaxeojltvibqmfvweim).
#
# Hintergrund: Supabase pausiert Free-Tier-Projekte nach 7 Tagen ohne
# API-/DB-Aktivität. Dieser Ping (1x täglich per Cron) hält das Projekt wach.
# Der anon-Key ist ein öffentlicher Client-Schlüssel (steht ohnehin im Web-Build).
#
# Installation auf dem Hetzner-Server (kol316), als User alex:
#   mkdir -p ~/bin && cp keepalive.sh ~/bin/bibelquiz-keepalive.sh
#   chmod +x ~/bin/bibelquiz-keepalive.sh
#   crontab -e   und folgende Zeile einfügen (täglich 04:23 Uhr):
#   23 4 * * * $HOME/bin/bibelquiz-keepalive.sh >> $HOME/bin/bibelquiz-keepalive.log 2>&1
#
# Prüfen, ob es läuft:  tail ~/bin/bibelquiz-keepalive.log

set -uo pipefail

URL="https://gwaxeojltvibqmfvweim.supabase.co/rest/v1/questions?select=id&limit=1"
ANON="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd3YXhlb2psdHZpYnFtZnZ3ZWltIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4NTY5MjgsImV4cCI6MjA5NjQzMjkyOH0.K7vtiGMeNomqaU6MSpAHBEfEIOgJlcpjagXzNn6Os0M"

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 \
  -H "apikey: $ANON" -H "Authorization: Bearer $ANON" "$URL")

echo "$(date '+%F %T') keepalive -> HTTP $code"
[ "$code" = "200" ] || exit 1
