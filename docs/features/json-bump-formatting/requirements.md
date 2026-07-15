# JSON bump formatting

Bumping a version must not restyle the file it touches. `jq_inplace`
re-serialises the whole document in jq's house style (2-space indent,
normalised spacing/escapes), so hand-formatted, 4-space or tab-indented
`package.json` / `-f` targets got whole-file diff churn in exactly the
commit that should be minimal — a quiet 2.0 regression vs 1.x, which
delegated to `npm version` (B-3 side effect). IDs backfilled per
[docs/features/README.md](../README.md); originated in issue #70.

| ID | Requirement | Status |
| --- | --- | --- |
| R-FMT-1 | Bumping a JSON file whose `version` member sits on its own line (the overwhelmingly common case) changes **only that line**; the rest of the file is byte-identical. | ✅ shipped — `json_set_version` (`lib/json.sh`); `test/json.bats` |
| R-FMT-2 | Postconditions on every write path: result parses, `.version` == new value; on postcondition failure nothing is replaced (existing tmp/err cleanup discipline). | ✅ shipped — surgical path probes the tmp with `jq -e '.version == $V'` (parse + value in one check) before the atomic `mv`; the fallback path holds by construction (jq exit 0 + non-empty output ⇒ parseable, and the expression itself sets `.version`) |
| R-FMT-3 | Fallback to full jq rewrite is allowed for ambiguous inputs and is logged, never silent. | ✅ shipped — `log_warn "… falling back to a full jq rewrite (formatting normalised)"`; `test/json.bats` |

Design notes:

- The surgical match is anchored on the **current** top-level value
  (`jq -r '.version'`), so nested `version` members with other values
  (lockfile entries, config blobs) never count as candidates. Anything
  other than exactly one candidate line — minified file, duplicate keys,
  a nested member holding the same value, the member sharing its line,
  or no member yet — takes the logged fallback. A wrong-line rewrite
  (same-value nested member while the top-level one is inline) is caught
  by the R-FMT-2 postcondition and also falls back.
- Preserved byte-for-byte on the surgical path: indentation (spaces or
  tabs), key spacing, trailing comma, CRLF endings, and a missing final
  newline.
- `package-lock.json` stays on the plain `jq_inplace` path: it is
  machine-generated (npm restyles it anyway) and needs a two-path update
  (`.version` + `.packages[""].version`), which is ambiguous by
  definition for the surgical rewrite. No fallback warning is emitted
  for it — the surgical path is never attempted.
- Runtime dependency surface is unchanged: bash string ops + `jq` only
  (R-DEP-1).

Modules: `lib/json.sh` (`json_set_version`, `jq_inplace`); call sites in
`lib/version.sh` (`do-packagefile-bump`, `bump-json-files`). Tests:
`test/json.bats` (15), `test/bumpfile.bats`.
