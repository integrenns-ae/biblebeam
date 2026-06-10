# Lichtpfad – Web-Admin (Phase 2)

React/Vite-Oberfläche zum Pflegen, Einreichen und Freigeben von Fragen.
Backend: **Supabase** (Postgres + Auth + RLS).

## Funktionen
- **Login** (E-Mail/Passwort via Supabase Auth)
- **Questions** – Liste mit Status-Filter, Anlegen & Bearbeiten
- **Editor** – mehrsprachig (en/de/ru): Frage, Erklärung, 4 Antwortoptionen + richtige markieren, Kategorie, Schwierigkeit, Bibelstelle, Status
- **Review** – Einreichungen (`pending`) freigeben/ablehnen
- Rollencheck: Schreiben/Freigeben erfordert `admin`-Rolle (per RLS erzwungen)

## Einrichtung (einmalig)

### 1. Supabase-Projekt anlegen
1. Auf <https://supabase.com> ein **kostenloses Projekt** erstellen.
2. Projekt-Ref + Keys findest du unter **Project Settings → API**.

### 2. Schema + Daten einspielen
Im Repo-Root (`bibelquiz/`):

```bash
# Projekt verknüpfen (DB-Passwort aus dem Supabase-Dashboard)
supabase link --project-ref DEIN-PROJECT-REF

# Schema (Tabellen + RLS) anwenden
supabase db push

# Seed erzeugen und einspielen (316 freigegebene EN-Fragen)
node scripts/build_seed.mjs
psql "DEINE-DB-CONNECTION-URL" -f supabase/seed.sql
# (Connection-URL: Project Settings → Database → Connection string)
```

### 3. Admin-Rolle setzen
Nach der ersten Registrierung in der Admin-App im **Supabase SQL Editor**:

```sql
update public.profiles set role = 'admin' where id = 'DEINE-USER-UUID';
```
(Die UUID zeigt die App im gelben Hinweisbanner an.)

### 4. Admin starten
```bash
cd admin
cp .env.example .env        # URL + anon key eintragen
npm install
npm run dev                 # http://localhost:5173
```

## Datenmodell (Kurz)
`categories` / `category_translations` · `questions` (status: draft/pending/approved/rejected) ·
`question_translations` (lang, prompt, explanation) · `answer_options` (is_correct) ·
`answer_option_translations` (lang, text) · `profiles` (role).
Schema: `../supabase/migrations/20260607000001_init.sql`.

## Hinweis
Die Flutter-App liest aktuell den **gebündelten Offline-Katalog**. Die Anbindung der
App an die Supabase-Fragen (Content-Pack-Sync) ist der nächste Integrationsschritt.
