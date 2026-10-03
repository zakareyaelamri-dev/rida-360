# Tests

No framework — plain Node. Each file inlines the `<script>` body of `index.html`
with `window`, `document`, `Chart` and the Supabase client stubbed, then asserts
against it.

```bash
node test/logic.test.js     # scoring engine + anonymity threshold
node test/render.test.js    # every page renderer, both languages, hostile data
```

`render.test.js` fills every employee / evaluation / training field with an
`<img src=x onerror=...>` payload and fails if it survives unescaped into the
produced HTML. It caught 16 injection sites that a manual pass had missed.

**Regenerate after editing index.html** — the script body is copied in, so these
files go stale. The slice runs from the line after `<script>` to the line before
`</script>`, and `let LANG='en';` is prepended because the declaration sits on the
first line of the slice's source.
