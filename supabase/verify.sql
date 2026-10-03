-- Paste into SQL Editor after the migration. Expected value is in brackets.
-- One line per check, so a partial paste cannot split a keyword.
select 'view_exists [true]' as check, (exists(select 1 from pg_views where schemaname='public' and viewname='my_evaluations'))::text as result
union all select 'rater_id_hidden [YES]', coalesce((select is_nullable from information_schema.columns where table_name='my_evaluations' and column_name='rater_id'),'missing')
union all select 'view_bypasses_rls [true]', (coalesce((select reloptions::text from pg_class where relname='my_evaluations'),'') not like '%security_invoker=true%')::text
union all select 'may_rate_exists [true]', (exists(select 1 from pg_proc where proname='may_rate'))::text
union all select 'helpers_security_definer [5]', (select count(*)::text from pg_proc where proname in ('effective_manager','my_employee_id','i_am_admin','my_perm','may_rate') and prosecdef)
union all select 'ev_read_excludes_target [true]', (coalesce((select qual::text from pg_policies where tablename='evaluations' and policyname='ev_read'),'') not like '%target_id = my_employee_id()%')::text
union all select 'ev_insert_checks_chain [true]', (coalesce((select with_check::text from pg_policies where tablename='evaluations' and policyname='ev_insert'),'') like '%may_rate%')::text
union all select 'ev_update_has_with_check [true]', ((select with_check from pg_policies where tablename='evaluations' and policyname='ev_update_rater') is not null)::text
union all select 'anon_cannot_read_view [true]', (case when to_regclass('public.my_evaluations') is null then 'view missing' else (not has_table_privilege('anon','public.my_evaluations','select'))::text end);
