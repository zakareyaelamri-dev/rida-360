-- Paste into SQL Editor after the migration. Every row must say PASS.
select 'my_evaluations view exists' as check,
       case when exists (select 1 from information_schema.views
                         where table_schema='public' and table_name='my_evaluations')
            then 'PASS' else 'FAIL' end as result
union all
select 'view hides rater_id',
       case when (select is_nullable from information_schema.columns
                  where table_schema='public' and table_name='my_evaluations'
                    and column_name='rater_id') = 'YES'
            then 'PASS' else 'FAIL' end
union all
select 'view is NOT security_invoker (must bypass RLS)',
       case when coalesce((select c.reloptions::text from pg_class c
                           join pg_namespace n on n.oid=c.relnamespace
                           where n.nspname='public' and c.relname='my_evaluations'),'')
                 not like '%security_invoker=true%'
            then 'PASS' else 'FAIL' end
union all
select 'may_rate() exists',
       case when exists (select 1 from pg_proc where proname='may_rate')
            then 'PASS' else 'FAIL' end
union all
select 'helpers are security definer',
       case when (select count(*) from pg_proc
                  where proname in ('effective_manager','my_employee_id','i_am_admin','my_perm','may_rate')
                    and prosecdef) = 5
            then 'PASS' else 'FAIL' end
union all
select 'ev_read no longer lets targets read the table',
       case when (select qual::text from pg_policies
                  where tablename='evaluations' and policyname='ev_read')
                 not like '%target_id = my_employee_id()%'
            then 'PASS' else 'FAIL' end
union all
select 'ev_insert enforces pending + chain',
       case when (select with_check::text from pg_policies
                  where tablename='evaluations' and policyname='ev_insert')
                 like '%may_rate%' and
            (select with_check::text from pg_policies
                  where tablename='evaluations' and policyname='ev_insert')
                 like '%pending%'
            then 'PASS' else 'FAIL' end
union all
select 'ev_update_rater has a WITH CHECK',
       case when (select with_check from pg_policies
                  where tablename='evaluations' and policyname='ev_update_rater') is not null
            then 'PASS' else 'FAIL' end
union all
select 'anon cannot read my_evaluations',
       case when not has_table_privilege('anon','public.my_evaluations','select')
            then 'PASS' else 'FAIL' end;
