-- ═══════════════════════════════════════════════════════════════
-- RIDA 360° — migration: rater anonymity + rating-chain enforcement
-- Run this on an EXISTING database (SQL Editor → New query → Run).
-- supabase_schema.sql is the fresh-install script and cannot be re-run:
-- it starts with CREATE TABLE and would abort the whole transaction.
-- This script is idempotent — running it twice is safe.
-- ═══════════════════════════════════════════════════════════════

-- ── 1. Helpers: security definer + pinned search_path ──────────
create or replace function effective_manager(emp_id text)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(
    (select manager_id from manager_overrides where employee_id = emp_id),
    (select case
      when e.is_ceo then null
      when e.role = 'Division Manager' then (select id from employees where is_ceo limit 1)
      when e.role in ('Dept Manager','Coordinator') then
        (select id from employees where role='Division Manager' and division=e.division limit 1)
      else coalesce(
        (select id from employees where role='Dept Manager' and division=e.division and dept=e.dept limit 1),
        (select id from employees where role='Division Manager' and division=e.division limit 1))
      end
     from employees e where e.id = emp_id)
  );
$$;

create or replace function my_employee_id()
returns text language sql stable security definer set search_path = public as $$
  select id from employees where auth_user = auth.uid();
$$;

create or replace function i_am_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from employees where auth_user = auth.uid()), false);
$$;

create or replace function my_perm(perm text)
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(
    (select case perm
      when 'employees' then perm_employees
      when 'raters' then perm_raters
      when 'approvals' then perm_approvals
      when 'allresults' then perm_allresults
      when 'org' then perm_org
      else false
    end from employees where auth_user = auth.uid()), false);
$$;

-- ── 2. Who may rate whom (mirrors the UI rating chain) ─────────
create or replace function may_rate(target text, rtype text)
returns boolean language sql stable security definer set search_path = public as $$
  select case rtype
    when 'self'        then target = my_employee_id()
    when 'manager'     then effective_manager(target) = my_employee_id()
    when 'subordinate' then effective_manager(my_employee_id()) = target
    when 'peer'        then (
      case when exists (select 1 from peer_assignments where employee_id = target)
        then exists (select 1 from peer_assignments
                     where employee_id = target and peer_id = my_employee_id())
        else exists (select 1 from employees me, employees tg
                     where me.id = my_employee_id() and tg.id = target
                       and me.id <> tg.id and not me.is_ceo
                       and me.division = tg.division and me.dept = tg.dept
                       and me.role = tg.role)
      end)
    else false
  end;
$$;

-- ── 3. Evaluation policies (dropped first — no CREATE OR REPLACE POLICY) ──
drop policy if exists ev_read on evaluations;
drop policy if exists ev_insert on evaluations;
drop policy if exists ev_update_rater on evaluations;

-- The evaluated employee is deliberately NOT granted access to the base table:
-- rater_id would reach their browser even if the UI hid it. They read their own
-- results through the anonymised view my_evaluations instead.
create policy ev_read on evaluations for select using (
  i_am_admin()
  or rater_id = my_employee_id()
  or effective_manager(target_id) = my_employee_id()
);

-- A rater may only ever write a row as 'pending', and only inside the chain.
create policy ev_insert on evaluations for insert with check (
  rater_id = my_employee_id() and status = 'pending' and may_rate(target_id, type)
);

create policy ev_update_rater on evaluations for update
  using (rater_id = my_employee_id() and status = 'pending')
  with check (rater_id = my_employee_id() and status = 'pending');

-- ── 4. Anonymised window for the evaluated employee ────────────
-- Plain view (security_invoker off) → runs with the owner's rights, so it is
-- the only path by which a target reads evaluations about themselves, and it
-- never exposes rater_id.
drop view if exists my_evaluations;
create view my_evaluations as
  select id, target_id, null::text as rater_id, type, scores, tech, dev_plan,
         status, eval_date, hidden_from_target
  from evaluations
  where target_id = my_employee_id()
    and status = 'confirmed'
    and hidden_from_target = false;
revoke all on my_evaluations from anon;
grant select on my_evaluations to authenticated;
