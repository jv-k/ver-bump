# Multi-format bump targets (`--bump` / `BUMP_FILES`)

> **Status: ✅ implemented** on `feat/bump-targets` — engine in
> [lib/textbump.sh](../../../lib/textbump.sh), covered by
> [test/bump-targets.bats](../../../test/bump-targets.bats). Origin: user
> feature request 2026-07-15 ("bump non-JSON files for Python / Go / YAML /
> …") + the follow-on "improve the existing JSON bump with jq as well".
> Tracked in [issue #92](https://github.com/jv-k/VerBump/issues/92).

Today every version-writing path assumes JSON + `jq`: `--source` / `SOURCE_FILE`
(the primary target, R-SRC-1) and `-f` / `--file` extras (`JSON_FILES`) both go
through `json_set_version` ([lib/json.sh](../../../lib/json.sh)). A Python,
Go, Rust, or Helm repo has its version in `pyproject.toml`, a `*.go` const, a
`Chart.yaml`, or a `VERSION`-adjacent file — none of which `jq` can touch — so
those files fall out of sync with the tag VerBump cuts.

This feature adds a general **bump target**: a file plus a *locator* that tells
VerBump where the version lives inside it. There are two locator kinds, chosen
per file, and both are explicit (no silent guessing that could rewrite the
wrong line):

1. **Text pattern locator** — a search string containing the literal token
   `{{version}}`. VerBump builds the *search* by substituting
   `{{version}}` → `V_PREV` and the *replacement* by substituting
   `{{version}}` → `V_NEW`, then rewrites only the matching line(s),
   byte-preserving the rest of the file. Pure `sed`/bash; **no new
   dependency**; works on any text format (Go, Makefile, Dockerfile, `.cfg`,
   plain `VERSION`, …).

2. **Structured path locator** — `@<path>` into a parsed document. JSON via
   `jq` (always available), TOML via a TOML helper (`tomlq`, or `yq -p toml`),
   YAML via `yq` — **used only when present** (they join `gh` as *conditional*
   dependencies). This is also where the existing JSON bump is improved: the
   path is no longer hard-wired to top-level `.version` — any `jq` path
   (`.tool.version`, `.package.version`, `.packages[""].version`) is valid.

## Grammar

A **spec** is `<file>` optionally followed by `:` and a locator:

| Spec form | Locator kind | Example |
| --- | --- | --- |
| `<file>` (no `:`) | structured default `.version`, by file type | `--bump composer.json` |
| `<file>:@<path>` | structured, explicit path | `--bump pyproject.toml:@tool.poetry.version` |
| `<file>:<pattern>` (pattern contains `{{version}}`) | text search/replace | `--bump main.go:'Version = "{{version}}"'` |

Disambiguation is by the first character after `:` — a leading `@` selects the
structured path locator; anything else is a text pattern and **must** contain
`{{version}}`. A bare `<file>` with an unknown (non-JSON/TOML/YAML) extension
is a usage error (exit `2`) that asks for an explicit `{{version}}` pattern —
VerBump never guesses a text pattern for an arbitrary file.

## Requirements (`R-TGT` bucket)

All modules: [lib/textbump.sh](../../../lib/textbump.sh) (engine),
[lib/args.sh](../../../lib/args.sh) (`--bump`),
[lib/config.sh](../../../lib/config.sh) (`BUMP_FILES`),
[verbump.sh](../../../verbump.sh) (`check-bump-deps` + `bump-target-files`
call sites), [lib/completions.sh](../../../lib/completions.sh),
[lib/usage.sh](../../../lib/usage.sh). All tests:
[test/bump-targets.bats](../../../test/bump-targets.bats).

| ID | Requirement | Status |
| --- | --- | --- |
| R-TGT-1 | `--bump <spec>` — long-only, repeatable, takes an arg — registers a bump target. `BUMP_FILES` config/env key mirrors it (newline-separated specs), with R-CFG-3 precedence (CLI `--bump` entries append to env/`.verbumprc` entries; nothing overrides, targets accumulate). | ✅ — `args.sh`, `config.sh`, `textbump.sh::resolve-bump-targets` |
| R-TGT-2 | **Text pattern locator** (`<file>:<pattern>`, pattern contains `{{version}}`): search = pattern with `{{version}}` → `V_PREV`, replacement = pattern with `{{version}}` → `V_NEW`. Only matching line(s) are rewritten; every other byte (indent, quoting, CRLF, missing trailing newline) is preserved. No external dependency. Zero matching lines → a loud `log_error` naming the resolved search string; **non-fatal** (the release continues, parity with a failed JSON extra in `bump-json-files`). | ✅ — `textbump.sh::_bt-text-set`, `bump-target-files` |
| R-TGT-3 | **Structured path locator** (`<file>:@<path>`, or a bare structured file defaulting to `.version`): JSON via `jq`, TOML via `tomlq`, YAML via `yq` — one `setpath()` filter serves all three (the jq-syntax kislyuk/yq suite). Generalises the JSON bump — any dotted path, not only top-level `.version`. When the path is exactly `.version` on a JSON file, reuse the surgical formatting-preserving rewrite (R-FMT-1); other paths / formats re-serialise structure-aware (formatting may normalise — documented, mirrors R-FMT-3). Simple dotted keys only (no `[`/`]`/`"`); exotic keys are rejected (exit `2`) pointing at the text pattern. | ✅ — `textbump.sh::_bt-struct-set`, `_bt-path-array` |
| R-TGT-4 | **Conditional dependencies** — `jq` stays always-required. A TOML/YAML *structured* locator requires its helper (`tomlq`; `yq`) only when actually used; absent → exit `3` with an install hint **and** the escape route (use a `{{version}}` text pattern instead, which needs no helper). Preflighted by `check-bump-deps` in the Verify phase, before any mutation. | ✅ — `textbump.sh::check-bump-deps`, `verbump.sh` |
| R-TGT-5 | **Postcondition** — a text write only renames its temp after an in-tmp `grep` confirms the replacement; a structured write is re-read through the locator and asserted to equal `V_NEW`. On any failure the file is left untouched and a loud `log_error` fires (**non-fatal**, mirrors R-FMT-2's "discard the tmp, don't commit a bad write"). | ✅ — `textbump.sh::_bt-text-set`, `bump-target-files` |
| R-TGT-6 | **Same-version no-op** — if a target already carries `V_NEW`, warn and skip it (no write, no `git add`); parity with `bump-json-files` / `do-packagefile-bump`. | ✅ — `textbump.sh::bump-target-files` |
| R-TGT-7 | **Dry-run** — each target emits a `[dry-run]` preview line to **stderr** (`would replace … → …` / `would set @path = 'V_NEW'`), no file touched, no staging (R-DRY-1/2 parity). | ✅ — `textbump.sh::bump-target-files` |
| R-TGT-8 | **Missing / unreadable file** — a missing target warns and is skipped (parity with `JSON_FILES`); a write that fails on an unwritable target is a loud non-fatal `log_error`, file left untouched. | ✅ — `textbump.sh::bump-target-files` |
| R-TGT-9 | **Staging + commit message** — every target that actually changed is `git add`ed and contributes an `updated <file>,` fragment (trailing space) to `GIT_MSG`, exactly like the existing JSON extras, so the bump commit and CHANGELOG list them uniformly. Honours dry-run (no `git add`). | ✅ — `textbump.sh::bump-target-files` |
| R-TGT-10 | **Back-compat** — `-f` / `--file <file.json>` is unchanged (JSON top-level `.version` via `bump-json-files`). `--bump` is the general form and handles JSON, TOML, YAML, and arbitrary text; pointed at a JSON file (`--bump foo.json`) it reproduces `-f foo.json` exactly. The two engines run independently; `--source` is unchanged. No existing invocation changes behaviour (full pre-existing suite stays green). | ✅ — `version.sh::bump-json-files` (untouched), `test/bumpfile.bats` |
| R-TGT-11 | **Completions + docs** — `--bump` is in all three completion emitters (free-form arg, no path-globbing since a spec isn't a plain file), `--help` (`usage.sh`), and the README (synopsis, flag table, config-key table, polyglot example). Help↔README flag parity test stays green. | ✅ — `completions.sh`, `usage.sh`, `README.md`, `test/args.bats` |

## Non-goals (this issue)

- **Reading** the current version *from* a non-JSON file as the source. `--source`
  stays JSON-only here; a multi-format version *source* (`--source pyproject.toml`
  reading `@tool.poetry.version`) is a natural follow-on that reuses the R-TGT
  locator engine, tracked separately. The git-tag fallback (R-SRC-2) already
  covers most source-less polyglot repos.
- **Placeholders beyond `{{version}}`** — no `{{major}}`/`{{minor}}`/`{{tag}}`
  in v1. The single `{{version}}` token keeps the search/replace unambiguous;
  richer tokens can extend R-TGT-2 later without breaking existing specs.
- **A curated per-ecosystem preset table** (e.g. "`--python` = these three
  files/paths"). Presets are sugar over R-TGT specs and can ship later once the
  primitive is proven.

## Notes

- **Why explicit patterns over auto-detected version lines** — VerBump is
  deliberately conservative about mutating files (see the surgical single-line
  JSON rewrite and its full-rewrite fallback warning, R-FMT). A regex that
  "finds the version-ish line" risks clobbering an unrelated `version` mention
  (a dependency pin, a comment, a second table). Making the user name the exact
  line via `{{version}}` — or an exact structured path — keeps the write
  auditable and the blast radius one line.
- **Why `{{version}}` and not `%s`/`$VERSION`** — double-brace is
  format-neutral: it can't collide with shell (`$`), printf (`%`), Go/TOML
  string syntax, or YAML anchors in the surrounding literal.
- The text-pattern path composes cleanly with `.verbumprc`: a polyglot repo
  declares its targets once in `BUMP_FILES` and every `VerBump` run keeps all
  of them in lock-step with the tag.

## Modules

- New: [lib/textbump.sh](../../../lib/textbump.sh) — spec parsing, text
  `{{version}}` search/replace, structured-path dispatch (`jq`/`tomlq`/`yq`),
  postcondition probe.
- Touched: [lib/args.sh](../../../lib/args.sh) (`--bump` capture),
  [lib/config.sh](../../../lib/config.sh) (`BUMP_FILES` key),
  [verbump.sh](../../../verbump.sh) (`check-bump-deps` in Verify,
  `bump-target-files` in Release alongside `bump-json-files`),
  [lib/completions.sh](../../../lib/completions.sh),
  [lib/usage.sh](../../../lib/usage.sh), [README.md](../../../README.md).
  `-f` / `bump-json-files` deliberately left untouched (R-TGT-10).

## Tests — [test/bump-targets.bats](../../../test/bump-targets.bats)

- Text pattern: `main.go` with `Version = "1.2.3"` rewrites only that line; a second unrelated `version` line untouched; CRLF + missing-final-newline preserved byte-for-byte (via `diff`).
- Zero-match pattern → `log_error` naming the resolved search string, file untouched.
- Text target already at the new version → warn + skip.
- Improved JSON: nested `@tool.version`; bare JSON file → surgical top-level `.version` (4-space indent preserved).
- Structured target already at the new version → warn + skip.
- Dry-run: preview to stderr, file byte-identical afterwards.
- Missing file → warn + skip.
- Grammar: pattern without `{{version}}`, bare non-structured file, `@path` on a text file → exit `2`.
- Conditional dep: TOML `@path` without `tomlq` → exit `3` with the dual hint (skipped when `tomlq` is installed).
- Accumulation: `BUMP_FILES` (config) + a `--bump` (CLI) → both applied.
- End-to-end (dry-run): `--bump` target shows in the release plan.
- Back-compat (`test/bumpfile.bats`, unchanged): `-f foo.json` still bumps top-level `.version`.
