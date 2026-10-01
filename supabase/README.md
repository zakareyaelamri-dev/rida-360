# Database workflow (Supabase CLI)

The schema is managed as **migrations**. `supabase_schema.sql` in the repo root
is the *fresh-install* script (it opens with `CREATE TABLE`) and is kept only as
a readable reference — never run it against a live database.

## One-time setup

This folder is **already linked** to project `cjcvtsdvgyjebwgigwsa`
(`supabase/.temp/project-ref`), so only the CLI and a login are missing.

```bash
# 1. install the CLI  (Windows, via Scoop)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase
#    no-install alternative, the CLI has been used here before:  npx supabase@latest <cmd>
#    (`npm i -g supabase` is NOT supported by the project)

# 2. authenticate — opens a browser, token is stored in your OS keyring
supabase login
```

If `supabase migration list` ever says the project is not linked, re-link with:

```bash
supabase link --project-ref cjcvtsdvgyjebwgigwsa
```

`supabase login` keeps the access token in the system keyring, outside the repo.
Nothing secret is ever committed.

Remote server: PostgreSQL 17.6.

## Applying migrations

```bash
supabase migration list     # what is applied remotely vs. local
supabase db push            # apply every pending migration
```

The first `db push` on this project may warn that the remote has no migration
history. That is expected — the tables were created by hand before migrations
existed. Every migration here is written to be **idempotent** (`create or
replace`, `drop ... if exists` before `create`), so applying one twice is safe.

## Adding a migration

```bash
supabase migration new short_description      # creates the timestamped file
# edit supabase/migrations/<timestamp>_short_description.sql
supabase db push
```

File names must keep the CLI's `YYYYMMDDHHMMSS_name.sql` form or they are
ignored.

## Verifying

`supabase/verify.sql` asserts that the anonymity and authorisation rules are
actually live — every row must read `PASS`. It is **not** a migration (it lives
outside `migrations/` so `db push` never runs it). Run it in the dashboard's SQL
Editor, or:

```bash
psql "$(supabase db url)" -f supabase/verify.sql
```

## Edge function

```bash
supabase functions deploy create-employee-login
```
