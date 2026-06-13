-- Globale, anonyme Antwort-Statistik je Frage (fuer Achievement "Schmaler Pfad":
-- eine Frage richtig beantwortet, die global <5% der Spieler richtig treffen).
-- Reine Aggregat-Zaehler ohne Nutzerbezug. Kein FK (stale qids unkritisch).
--
-- Sicherheit wie bei difficulty_votes: anon hat KEINEN Direktzugriff; alles laeuft
-- ueber die SECURITY-DEFINER-Funktion record_answers.

create table public.question_stats (
  question_id uuid   primary key,
  seen        bigint not null default 0,
  correct     bigint not null default 0
);
alter table public.question_stats enable row level security;
-- bewusst keine Policy/kein Grant fuer anon.

-- Nimmt ein JSON-Array [{qid, correct}, ...] (alle Antworten eines Quiz),
-- erhoeht die Zaehler und liefert die qids zurueck, die korrekt beantwortet
-- wurden UND global selten sind (genug Stichprobe vorausgesetzt).
create or replace function public.record_answers(p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item    jsonb;
  v_qid     uuid;
  v_correct boolean;
  v_seen    bigint;
  v_corr    bigint;
  v_rare    jsonb := '[]'::jsonb;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'items must be a json array';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    begin
      v_qid := (v_item->>'qid')::uuid;
    exception when others then
      continue; -- ungueltige qid ueberspringen
    end;
    v_correct := coalesce((v_item->>'correct')::boolean, false);

    insert into question_stats (question_id, seen, correct)
    values (v_qid, 1, case when v_correct then 1 else 0 end)
    on conflict (question_id) do update
      set seen    = question_stats.seen + 1,
          correct = question_stats.correct + (case when v_correct then 1 else 0 end)
    returning seen, correct into v_seen, v_corr;

    -- "schmaler Pfad": korrekt + global <5% bei ausreichender Stichprobe (>=20)
    if v_correct and v_seen >= 20 and (v_corr::numeric / v_seen) < 0.05 then
      v_rare := v_rare || to_jsonb(v_qid::text);
    end if;
  end loop;

  return jsonb_build_object('rare', v_rare);
end;
$$;

revoke all on function public.record_answers(jsonb) from public;
grant execute on function public.record_answers(jsonb) to anon, authenticated;
