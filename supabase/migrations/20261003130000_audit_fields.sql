-- ═══════════════════════════════════════════════════════════════
-- Audit fields were whatever the browser sent.
--
-- confirmEval/confirmAll post confirmed_by: USER.id and saveTrain posts
-- created_by: USER.id, so the record of who approved an evaluation or who
-- created a training was client-supplied and could name anyone. These are the
-- fields an HR dispute would turn on, so the server sets them now.
-- Idempotent.
-- ═══════════════════════════════════════════════════════════════

create or replace function set_eval_audit()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  -- only stamp on the transition into 'confirmed', so a later edit of a
  -- confirmed row keeps the original approver
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

drop trigger if exists evaluations_audit on evaluations;
create trigger evaluations_audit before insert or update on evaluations
  for each row execute function set_eval_audit();

create or replace function set_training_creator()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := coalesce(my_employee_id(), new.created_by);
  else
    new.created_by := old.created_by;   -- an editor never becomes the creator
  end if;
  return new;
end $$;

drop trigger if exists trainings_creator on trainings;
create trigger trainings_creator before insert or update on trainings
  for each row execute function set_training_creator();
