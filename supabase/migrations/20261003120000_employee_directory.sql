-- ═══════════════════════════════════════════════════════════════
-- Narrow what one employee may read about another.
--
-- emp_read granted every signed-in user SELECT on every column of every
-- employee row: business email, phone, auth_user (their Auth account id),
-- is_admin and the perm_* flags. The UI only ever shows contact details on
-- the admin pages, but the data reached every browser regardless.
--
-- The roster the app needs for names, titles and the rating chain now comes
-- from a view holding only those columns. The base table is readable by the
-- admin and by each employee for their own row.
-- Idempotent.
-- ═══════════════════════════════════════════════════════════════

create or replace view employees_directory as
  select id, name, title, role, division, dept, is_admin, is_ceo
  from employees;
revoke all on employees_directory from anon;
grant select on employees_directory to authenticated;

drop policy if exists emp_read on employees;
create policy emp_read on employees for select using (
  i_am_admin() or id = my_employee_id()
);
