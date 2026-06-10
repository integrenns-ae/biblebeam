-- Mehrere Kategorien pro Frage (n:m) + Tag-Dimension + Schwierigkeit.
-- Kategorien sind jetzt Roh-Tags mit kind = 'testament' | 'book' | 'type'.

alter table public.categories add column if not exists kind text;

create table if not exists public.question_categories (
  question_id uuid not null references public.questions(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete cascade,
  primary key (question_id, category_id)
);
create index if not exists question_categories_category_idx
  on public.question_categories (category_id);

alter table public.question_categories enable row level security;

-- Sichtbarkeit/Bearbeitbarkeit folgt der zugehörigen Frage (wie andere Kind-Tabellen).
create policy qc_select on public.question_categories for select
  using (exists (select 1 from public.questions q where q.id = question_id
    and (q.status = 'approved' or q.created_by = auth.uid() or public.is_admin())));
create policy qc_write on public.question_categories for all
  using (exists (select 1 from public.questions q where q.id = question_id
    and (public.is_admin() or (q.created_by = auth.uid() and q.status in ('draft','pending')))))
  with check (exists (select 1 from public.questions q where q.id = question_id
    and (public.is_admin() or (q.created_by = auth.uid() and q.status in ('draft','pending')))));
