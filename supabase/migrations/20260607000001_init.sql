-- Bibelquiz – Initiales Schema (Supabase / Postgres)
-- Mehrsprachig (de/ru/en) über Übersetzungstabellen. RLS aktiv.

create extension if not exists "pgcrypto";

-- ─────────────────────────────────────────────────────────
-- Profile (1:1 zu auth.users)
-- ─────────────────────────────────────────────────────────
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  locale       text not null default 'en',
  role         text not null default 'user' check (role in ('user','admin')),
  created_at   timestamptz not null default now()
);

-- Profil automatisch bei Registrierung anlegen
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1)));
  return new;
end; $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Admin-Check ohne RLS-Rekursion
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- updated_at-Helfer
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

-- ─────────────────────────────────────────────────────────
-- Kategorien
-- ─────────────────────────────────────────────────────────
create table public.categories (
  id    uuid primary key default gen_random_uuid(),
  slug  text unique not null,
  icon  text,
  color text,
  sort  int not null default 0
);
create table public.category_translations (
  category_id uuid not null references public.categories(id) on delete cascade,
  lang        text not null,
  name        text not null,
  primary key (category_id, lang)
);

-- ─────────────────────────────────────────────────────────
-- Fragen
-- ─────────────────────────────────────────────────────────
create type public.question_status as enum ('draft','pending','approved','rejected');

create table public.questions (
  id              uuid primary key default gen_random_uuid(),
  category_id     uuid references public.categories(id) on delete set null,
  difficulty      int not null default 1,
  bible_reference text,
  status          public.question_status not null default 'pending',
  source          text,
  created_by      uuid references auth.users(id) on delete set null,
  reviewed_by     uuid references auth.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index on public.questions (status);
create index on public.questions (category_id);
create trigger questions_touch before update on public.questions
  for each row execute function public.touch_updated_at();

create table public.question_translations (
  question_id uuid not null references public.questions(id) on delete cascade,
  lang        text not null,
  prompt      text not null,
  explanation text,
  primary key (question_id, lang)
);

create table public.answer_options (
  id          uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete cascade,
  is_correct  boolean not null default false,
  sort        int not null default 0
);
create index on public.answer_options (question_id);

create table public.answer_option_translations (
  option_id uuid not null references public.answer_options(id) on delete cascade,
  lang      text not null,
  text      text not null,
  primary key (option_id, lang)
);

-- ─────────────────────────────────────────────────────────
-- Row Level Security
-- ─────────────────────────────────────────────────────────
alter table public.profiles                   enable row level security;
alter table public.categories                 enable row level security;
alter table public.category_translations      enable row level security;
alter table public.questions                  enable row level security;
alter table public.question_translations      enable row level security;
alter table public.answer_options             enable row level security;
alter table public.answer_option_translations enable row level security;

-- Profile: jeder sieht sein eigenes; Admin sieht alle. Update nur eigenes (Rolle nicht änderbar per Default-Policy).
create policy profiles_select on public.profiles for select
  using (id = auth.uid() or public.is_admin());
create policy profiles_update on public.profiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- Kategorien: für alle lesbar; schreiben nur Admin.
create policy categories_read on public.categories for select using (true);
create policy categories_admin on public.categories for all
  using (public.is_admin()) with check (public.is_admin());
create policy cat_tr_read on public.category_translations for select using (true);
create policy cat_tr_admin on public.category_translations for all
  using (public.is_admin()) with check (public.is_admin());

-- Fragen: lesen nach Sichtbarkeit (freigegeben ODER eigene ODER Admin).
create policy questions_select on public.questions for select
  using (status = 'approved' or created_by = auth.uid() or public.is_admin());
-- Einreichen: angemeldete Nutzer (Status 'pending'); Admin darf jeden Status.
create policy questions_insert on public.questions for insert to authenticated
  with check (public.is_admin() or (created_by = auth.uid() and status = 'pending'));
-- Bearbeiten: Admin immer; Ersteller nur solange draft/pending.
create policy questions_update on public.questions for update
  using (public.is_admin() or (created_by = auth.uid() and status in ('draft','pending')))
  with check (public.is_admin() or (created_by = auth.uid() and status in ('draft','pending')));
create policy questions_delete on public.questions for delete
  using (public.is_admin() or (created_by = auth.uid() and status in ('draft','pending')));

-- Kind-Tabellen folgen der Sichtbarkeit/Bearbeitbarkeit der Frage.
create policy qtr_select on public.question_translations for select
  using (exists (select 1 from public.questions q where q.id = question_id and (q.status='approved' or q.created_by=auth.uid() or public.is_admin())));
create policy qtr_write on public.question_translations for all
  using (exists (select 1 from public.questions q where q.id = question_id and (public.is_admin() or (q.created_by=auth.uid() and q.status in ('draft','pending')))))
  with check (exists (select 1 from public.questions q where q.id = question_id and (public.is_admin() or (q.created_by=auth.uid() and q.status in ('draft','pending')))));

create policy opt_select on public.answer_options for select
  using (exists (select 1 from public.questions q where q.id = question_id and (q.status='approved' or q.created_by=auth.uid() or public.is_admin())));
create policy opt_write on public.answer_options for all
  using (exists (select 1 from public.questions q where q.id = question_id and (public.is_admin() or (q.created_by=auth.uid() and q.status in ('draft','pending')))))
  with check (exists (select 1 from public.questions q where q.id = question_id and (public.is_admin() or (q.created_by=auth.uid() and q.status in ('draft','pending')))));

create policy opttr_select on public.answer_option_translations for select
  using (exists (select 1 from public.answer_options o join public.questions q on q.id=o.question_id where o.id = option_id and (q.status='approved' or q.created_by=auth.uid() or public.is_admin())));
create policy opttr_write on public.answer_option_translations for all
  using (exists (select 1 from public.answer_options o join public.questions q on q.id=o.question_id where o.id = option_id and (public.is_admin() or (q.created_by=auth.uid() and q.status in ('draft','pending')))))
  with check (exists (select 1 from public.answer_options o join public.questions q on q.id=o.question_id where o.id = option_id and (public.is_admin() or (q.created_by=auth.uid() and q.status in ('draft','pending')))));
