-- Review-Modus (in-App, durch Zugangscode geschützt):
-- anon darf Frage-Inhalte korrigieren (Fragetext, Erklärung, Optionstext, richtige Antwort).
-- Bewusst offen gehalten (nur App-Code-Gate) – Familienprojekt, akzeptierter Tradeoff.
-- Kein INSERT/DELETE, keine anderen Tabellen.

grant update on public.question_translations       to anon;
grant update on public.answer_option_translations  to anon;
grant update on public.answer_options              to anon;

create policy review_qtr_update on public.question_translations
  for update to anon using (true) with check (true);
create policy review_optr_update on public.answer_option_translations
  for update to anon using (true) with check (true);
create policy review_opt_update on public.answer_options
  for update to anon using (true) with check (true);
