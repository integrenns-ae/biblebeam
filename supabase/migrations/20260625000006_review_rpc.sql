-- Review-Schreibzugriff ohne Admin-Login im Client.
--
-- Vorher meldete sich die App mit einem festen Supabase-Admin-Konto an, dessen
-- Zugangsdaten im OEFFENTLICHEN Web-Build lagen. Das ist ersetzt durch zwei
-- SECURITY-DEFINER-RPCs, die hinter einem Zugangscode NUR die schmalen
-- Review-Writes erlauben (Prompt-Text, Options-Text, is_correct) -- nicht den
-- vollen Admin-Umfang.
--
-- Sicherheit (wie bei vote_question_difficulty):
--   * anon hat KEINE direkten Rechte auf question_translations /
--     answer_option_translations / answer_options (nur Lesen, wie bisher).
--   * Der Zugangscode liegt NICHT im Repo und NICHT im Client als Klartext,
--     sondern nur als bcrypt-Hash in der privaten Tabelle review_config
--     (RLS an, kein anon-Grant). Der Hash wird EINMALIG manuell per psql
--     gesetzt (siehe unten) -- nie in eine Migration committen.
--   * Beide Funktionen pruefen den Code serverseitig; der Client-Gate ist nur
--     UX-Komfort.

create table if not exists public.review_config (
  key   text primary key,
  value text not null
);
alter table public.review_config enable row level security;
-- bewusst keine Policy/kein Grant: nur die SECURITY-DEFINER-Funktionen lesen das.

-- Prueft, ob ein eingegebener Code gueltig ist (Gate beim Betreten des Reviews).
create or replace function public.review_check_code(p_code text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_hash text;
begin
  if p_code is null or length(p_code) < 4 then
    return false;
  end if;
  select value into v_hash from review_config where key = 'review_code_hash';
  if v_hash is null then
    return false; -- Code noch nicht eingerichtet -> Review gesperrt
  end if;
  return crypt(p_code, v_hash) = v_hash;
end;
$$;

-- Speichert die Korrekturen einer Frage in EINER Sprache.
-- p_options: jsonb-Array [{ "id": "<uuid>", "text": "...", "is_correct": true }, ...]
create or replace function public.review_save_question(
  p_code        text,
  p_question_id uuid,
  p_lang        text,
  p_prompt      text,
  p_options     jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_opt jsonb;
begin
  if not public.review_check_code(p_code) then
    raise exception 'invalid review code';
  end if;
  if p_lang not in ('de', 'en', 'ru') then
    raise exception 'invalid lang';
  end if;
  if not exists (select 1 from questions where id = p_question_id) then
    raise exception 'unknown question';
  end if;

  insert into question_translations (question_id, lang, prompt)
  values (p_question_id, p_lang, trim(p_prompt))
  on conflict (question_id, lang) do update set prompt = excluded.prompt;

  for v_opt in select * from jsonb_array_elements(coalesce(p_options, '[]'::jsonb))
  loop
    -- Nur Optionen, die wirklich zu dieser Frage gehoeren (Schutz vor
    -- untergeschobenen fremden Option-IDs).
    if not exists (
      select 1 from answer_options
      where id = (v_opt->>'id')::uuid and question_id = p_question_id
    ) then
      raise exception 'option % does not belong to question', v_opt->>'id';
    end if;

    insert into answer_option_translations (option_id, lang, text)
    values ((v_opt->>'id')::uuid, p_lang, trim(v_opt->>'text'))
    on conflict (option_id, lang) do update set text = excluded.text;

    update answer_options
    set is_correct = (v_opt->>'is_correct')::boolean
    where id = (v_opt->>'id')::uuid;
  end loop;
end;
$$;

revoke all on function public.review_check_code(text) from public;
revoke all on function public.review_save_question(text, uuid, text, text, jsonb) from public;
grant execute on function public.review_check_code(text) to anon, authenticated;
grant execute on function public.review_save_question(text, uuid, text, text, jsonb) to anon, authenticated;

-- PostgREST-Schema-Cache neu laden, sonst PGRST202 fuer die neuen RPCs.
notify pgrst, 'reload schema';

-- ----------------------------------------------------------------------------
-- EINMALIG manuell ausfuehren (NICHT committen), um den Zugangscode zu setzen:
--
--   insert into review_config (key, value)
--   values ('review_code_hash', crypt('DEIN-NEUER-CODE', gen_salt('bf')))
--   on conflict (key) do update set value = excluded.value;
--
-- Code aendern = dieselbe Zeile mit neuem Klartext erneut ausfuehren.
-- ----------------------------------------------------------------------------
