-- ═══════════════════════════════════════════════════════════════
-- RIDA 360° Assessment — Supabase schema
-- Run this in: Supabase Dashboard → SQL Editor → New query → Run
-- ═══════════════════════════════════════════════════════════════

-- ── Employees ──────────────────────────────────────────────────
create table employees (
  id text primary key,                      -- RTS-001
  auth_user uuid references auth.users,     -- linked Supabase Auth account
  name text not null,
  title text,
  role text not null check (role in ('CEO','Division Manager','Dept Manager','Coordinator','Employee')),
  division text,                            -- RSS / OPS / SLS / QHSE / RAS
  dept text,
  is_admin boolean default false,
  is_ceo boolean default false,
  phone text,
  email text,
  created_at timestamptz default now(),
  -- Sub-permissions for admins (ignored when is_admin = false).
  -- All default true so existing full admins are unaffected; set any
  -- to false to grant a "limited admin" who can't do that action.
  perm_employees boolean not null default true,
  perm_raters boolean not null default true,
  perm_approvals boolean not null default true,
  perm_allresults boolean not null default true,
  perm_org boolean not null default true
);

-- ── Manager overrides (admin-set, wins over auto chain) ────────
create table manager_overrides (
  employee_id text primary key references employees(id) on delete cascade,
  manager_id text not null references employees(id) on delete cascade,
  set_by text references employees(id),
  created_at timestamptz default now()
);

-- ── Peer assignments (admin-picked peer raters) ────────────────
create table peer_assignments (
  employee_id text references employees(id) on delete cascade,
  peer_id text references employees(id) on delete cascade,
  primary key (employee_id, peer_id)
);

-- ── Evaluations ────────────────────────────────────────────────
create table evaluations (
  id uuid primary key default gen_random_uuid(),
  target_id text not null references employees(id) on delete cascade,
  rater_id text not null references employees(id) on delete cascade,
  type text not null check (type in ('self','manager','peer','subordinate')),
  scores jsonb not null,          -- {"A1":[5,4,...], "A2":[...] ...}
  tech jsonb,                     -- {"T1":85,"T2":90,...} manager evals only
  dev_plan jsonb,                 -- {strengths, areas, goals, recommend}
  status text not null default 'pending' check (status in ('pending','confirmed')),
  eval_date date default current_date,
  confirmed_at timestamptz,
  confirmed_by text references employees(id),
  hidden_from_target boolean not null default false,  -- admin can hide a confirmed eval from the employee it's about
  unique (target_id, rater_id)
);

-- ── Trainings ──────────────────────────────────────────────────
create table trainings (
  id uuid primary key default gen_random_uuid(),
  emp_id text not null references employees(id) on delete cascade,
  name text not null,
  axis text default 'GEN',        -- A1..A7 or GEN
  level text check (level in ('basic','inter','adv')),
  type text check (type in ('course','workshop','ojt','cert','online')),
  provider text,
  start_date date,
  dur_val numeric,
  dur_unit text check (dur_unit in ('hours','days','weeks','months')),
  status text default 'planned' check (status in ('planned','progress','done','cancel')),
  notes text,
  created_by text references employees(id),
  created_at timestamptz default now()
);

-- ═══════════════════════════════════════════════════════════════
-- Helper: resolve the effective manager of an employee (auto chain + override)
-- ═══════════════════════════════════════════════════════════════
create or replace function effective_manager(emp_id text)
returns text language sql stable as $$
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

-- Helper: current logged-in employee id
create or replace function my_employee_id()
returns text language sql stable as $$
  select id from employees where auth_user = auth.uid();
$$;

create or replace function i_am_admin()
returns boolean language sql stable as $$
  select coalesce((select is_admin from employees where auth_user = auth.uid()), false);
$$;

-- Sub-permission check for limited admins. perm must be one of:
-- 'employees' | 'raters' | 'approvals' | 'allresults' | 'org'
create or replace function my_perm(perm text)
returns boolean language sql stable as $$
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

-- ═══════════════════════════════════════════════════════════════
-- Row Level Security
-- ═══════════════════════════════════════════════════════════════
alter table employees enable row level security;
alter table evaluations enable row level security;
alter table trainings enable row level security;
alter table manager_overrides enable row level security;
alter table peer_assignments enable row level security;

-- Employees: everyone signed-in reads basic directory (needed for names in UI);
-- only admin writes.
create policy emp_read on employees for select using (auth.uid() is not null);
create policy emp_admin_write on employees for all using (i_am_admin() and my_perm('employees'));

-- Evaluations:
--  read: admin, the rater who wrote it, the target's effective manager,
--        the target himself ONLY when confirmed and not hidden_from_target
--        (and never learns rater identity — enforce that in the UI by
--        aggregating, never selecting rater_id for targets)
create policy ev_read on evaluations for select using (
  i_am_admin()
  or rater_id = my_employee_id()
  or effective_manager(target_id) = my_employee_id()
  or (target_id = my_employee_id() and status = 'confirmed' and hidden_from_target = false)
);
--  insert: the rater inserts own evaluation
create policy ev_insert on evaluations for insert with check (rater_id = my_employee_id());
--  update: rater edits while pending; admin can update anything (confirm/reject)
create policy ev_update_rater on evaluations for update
  using (rater_id = my_employee_id() and status = 'pending');
create policy ev_admin_all on evaluations for all using (i_am_admin() and my_perm('approvals'));

-- Trainings: admin all; direct manager manages; employee reads own
create policy tr_read on trainings for select using (
  i_am_admin() or emp_id = my_employee_id() or effective_manager(emp_id) = my_employee_id()
);
create policy tr_mgr_write on trainings for insert with check (
  i_am_admin() or effective_manager(emp_id) = my_employee_id()
);
create policy tr_mgr_update on trainings for update using (
  i_am_admin() or effective_manager(emp_id) = my_employee_id()
);
create policy tr_mgr_delete on trainings for delete using (
  i_am_admin() or effective_manager(emp_id) = my_employee_id()
);

-- Overrides & peer assignments: admin only (others read to compute chains)
create policy ov_read on manager_overrides for select using (auth.uid() is not null);
create policy ov_admin on manager_overrides for all using (i_am_admin() and my_perm('raters'));
create policy pa_read on peer_assignments for select using (auth.uid() is not null);
create policy pa_admin on peer_assignments for all using (i_am_admin() and my_perm('raters'));

-- ═══════════════════════════════════════════════════════════════
-- Seed: divisions reference (informational) + first admin
-- After creating your own auth user (Authentication → Users → Add user),
-- link it here by replacing YOUR-AUTH-UUID:
-- ═══════════════════════════════════════════════════════════════
insert into employees (id, name, title, role, division, dept, is_admin) values
 ('RTS-001','Zack','HR Manager','Dept Manager','RSS','Human Resources', true),
 ('RTS-000','CEO','Chief Executive Officer','CEO','—','Executive', false);
-- update employees set auth_user = 'YOUR-AUTH-UUID' where id = 'RTS-001';
