-- Crowd-Einstufung der Schwierigkeit.
-- Spieler melden je Frage "zu leicht" (-1) oder "zu schwer" (+1). Erreicht die
-- Netto-Differenz +/-10, wird die Frage automatisch eine Stufe hoch/runter
-- gestuft (1=leicht .. 3=schwer) und die Stimmen werden zurueckgesetzt.
--
-- Sicherheit: anon hat KEINE Rechte auf difficulty_votes oder questions. Der
-- gesamte Pfad laeuft ueber die SECURITY-DEFINER-Funktion unten (laeuft als
-- Eigentuemer, kann questions kontrolliert aendern). So bleibt die offene
-- anon-UPDATE-Flaeche auf ein Minimum beschraenkt.

create table public.difficulty_votes (
  question_id uuid     not null references public.questions(id) on delete cascade,
  client_id   text     not null,
  vote        smallint not null check (vote in (-1, 1)),
  created_at  timestamptz not null default now(),
  primary key (question_id, client_id)
);
alter table public.difficulty_votes enable row level security;
-- bewusst keine Policy/kein Grant fuer anon: Zugriff nur via RPC.

create or replace function public.vote_question_difficulty(
  p_question_id uuid,
  p_client_id   text,
  p_direction   int
) returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_net     int;
  v_diff    int;
  v_changed boolean := false;
begin
  if p_direction not in (-1, 1) then
    raise exception 'invalid direction';
  end if;
  if p_client_id is null or length(p_client_id) < 4 then
    raise exception 'invalid client';
  end if;

  select difficulty into v_diff from questions where id = p_question_id;
  if v_diff is null then
    raise exception 'unknown question';
  end if;

  -- Eine wirksame Stimme pro Geraet/Frage (Meinungsaenderung erlaubt).
  insert into difficulty_votes (question_id, client_id, vote)
  values (p_question_id, p_client_id, p_direction)
  on conflict (question_id, client_id)
  do update set vote = excluded.vote, created_at = now();

  select coalesce(sum(vote), 0) into v_net
  from difficulty_votes where question_id = p_question_id;

  if v_net >= 10 and v_diff < 3 then
    update questions set difficulty = v_diff + 1 where id = p_question_id;
    delete from difficulty_votes where question_id = p_question_id;
    v_diff := v_diff + 1; v_net := 0; v_changed := true;
  elsif v_net <= -10 and v_diff > 1 then
    update questions set difficulty = v_diff - 1 where id = p_question_id;
    delete from difficulty_votes where question_id = p_question_id;
    v_diff := v_diff - 1; v_net := 0; v_changed := true;
  end if;

  return json_build_object('difficulty', v_diff, 'net', v_net, 'changed', v_changed);
end;
$$;

revoke all on function public.vote_question_difficulty(uuid, text, int) from public;
grant execute on function public.vote_question_difficulty(uuid, text, int) to anon, authenticated;
