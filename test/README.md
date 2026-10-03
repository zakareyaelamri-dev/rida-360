# Tests

No framework, no dependencies — plain Node.

```bash
node test/harness.js          # run every case
node test/harness.js render   # run one case
```

Exit code is non-zero when anything fails, so it drops straight into CI or a
git hook.

## How it works

`harness.js` reads `index.html` at run time, pulls out the inline `<script>`
block, and evaluates it in a `vm` context on top of `stubs.js` — which fakes
`document`, `window`, `localStorage`, `Chart` and the Supabase client. The app
source is never copied or edited, so **the tests cannot go stale**: change
`index.html` and the next run tests the change.

To confirm that for yourself, remove an `esc(...)` call from `index.html` and
re-run — `render` fails and names the page.

## Cases

**`cases/logic.js`** — the assessment engine. Behavioural average, no final
grade until KPIs are in, `80 × 0.4 + 90 × 0.6 = 86`, the grade labels in both
languages, weight redistribution, and the rater-anonymity threshold (a group of
fewer than 3 confirmed peers is withheld from the employee but shown to their
manager).

**`cases/render.js`** — every page renderer and modal, in English and Arabic,
with `<img src=x onerror=...>` planted in every employee, evaluation and
training field. Fails if the payload reaches the HTML unescaped. This case found
18 injection sites that a manual review had missed, so widen it rather than
trusting a read-through: add a field to the fixtures, add a `check(...)` line
for any new page, and anything that interpolates it unescaped shows up by name.

## Adding a case

Drop a file in `cases/`. It runs inside the app's scope, so every app global
(`DB`, `USER`, `LANG`, `computeResults`, the `pg*` functions) is already in
scope. Increment `failures` to fail the run.
