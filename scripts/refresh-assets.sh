#!/usr/bin/env bash
# Zieht den aktuellen Fragenkatalog aus der Supabase-DB (Single Source of Truth)
# und schreibt assets/questions_en.json + questions_de.json neu.
# Danach committen + ./scripts/deploy.sh ausführen.
#
# Aufruf:  ./scripts/refresh-assets.sh   (fragt das DB-Passwort interaktiv)
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

HOST="db.gwaxeojltvibqmfvweim.supabase.co"
read -r -s -p "Supabase DB-Passwort (postgres): " PGPW
echo
export PGPASSWORD="$PGPW"
CONN="host=$HOST port=5432 user=postgres dbname=postgres sslmode=require connect_timeout=30"

echo "==> Dump aus der DB..."
psql "$CONN" -t -A -o /tmp/db_dump.json <<'SQL'
select coalesce(json_agg(j), '[]') from (
  select q.id, q.difficulty,
    (select jsonb_object_agg(t.lang, t.prompt) from question_translations t where t.question_id=q.id) as prompts,
    (select jsonb_agg(jsonb_build_object('sort',o.sort,'correct',o.is_correct,
        'texts',(select jsonb_object_agg(ot.lang, ot.text) from answer_option_translations ot where ot.option_id=o.id))
       order by o.sort) from answer_options o where o.question_id=q.id) as options,
    (select jsonb_agg(jsonb_build_object('slug',c.slug,'kind',c.kind))
       from question_categories qc join categories c on c.id=qc.category_id where qc.question_id=q.id) as cats
  from questions q where q.status='approved'
) j;
SQL
unset PGPASSWORD

node scripts/build_assets_from_db.mjs
echo "==> Fertig. Nächste Schritte: git commit + ./scripts/deploy.sh"
