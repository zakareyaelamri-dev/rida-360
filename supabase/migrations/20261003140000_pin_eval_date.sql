-- ═══════════════════════════════════════════════════════════════
-- eval_date came from the browser (submitEval posts today's date), so a rater
-- could backdate their own evaluation — the field that says whether they
-- submitted on time. The server sets it on insert now, and a rater cannot
-- change it afterwards. The admin still can, because they are the one who
-- edits confirmed evaluations and may need to correct a record.
-- Replaces set_eval_audit from 20261003130000; the trigger itself is unchanged.
-- Idempotent.
-- ═══════════════════════════════════════════════════════════════

create or replace function set_eval_audit()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- submission date: stamped by the server, correctable only by the admin
  if tg_op = 'INSERT' then
    new.eval_date := current_date;
  elsif not i_am_admin() then
    new.eval_date := old.eval_date;
  end if;

  -- approval: stamped on the transition into 'confirmed' only, so a later
  -- admin edit of a confirmed row keeps the original approver
  if new.status = 'confirmed'
     and (tg_op = 'INSERT' or old.status is distinct from 'confirmed') then
    new.confirmed_by := coalesce(my_employee_id(), new.confirmed_by);
    new.confirmed_at := now();
  elsif new.status is distinct from 'confirmed' then
    new.confirmed_by := null;
    new.confirmed_at := null;
  else
    new.confirmed_by := old.confirmed_by;
    new.confirmed_at := old.confirmed_at;
  end if;
  return new;
end $$;
