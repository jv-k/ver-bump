# `--dry-run --json` — structured release preview

Machine-readable answer to *"what would this release do?"* (issue #107).
Extends the R-OUT bucket started by `--quiet`
([ui-output](../ui-output/requirements.md)): `--quiet` gives machines the
*result* of a release; `--json` gives them the *plan* before one.

| ID | Requirement | Status |
| --- | --- | --- |
| R-OUT-5 | `--dry-run --json` emits exactly one JSON object (`"schema": "verbump.dry-run/v1"`) on stdout via the R-OUT-1 FD-3 channel — decoration, prompts, and `[dry-run]` lines stay on stderr. `effects[]` is ordered as `main()` would execute the steps and contains **only** the operations that would actually run (each site's `FLAG`/`DO_` guard decides membership — no "skipped" noise). Values are jq-escaped: commit messages / paths with quotes, newlines, or backslashes round-trip byte-exact. Counts and booleans are typed (`changelog.entries` number; `tag.annotated`/`tag.signed`, `github-release.prerelease` booleans). | ✅ shipped — `test/dry-run-json.bats` |
| R-OUT-6 | `--json` is **preview-only** and prompt-free by construction: without `--dry-run` it exits `2` naming the fix; without `--yes`, `-v`, a forced bump level, or `--preid` it exits `2` (mirrors R-OUT-2). `--json=value` exits `2` (boolean flag, R-OPT-2). `FLAG_JSON` is CLI-only — reset in `process-arguments`; an rc key or env var can never switch JSON mode on. | ✅ shipped — `test/dry-run-json.bats` |
| R-OUT-7 | Composes with the rest of the output contract: `--quiet --json` emits only the JSON object (the bare-version line is skipped; the version lives at `.version.to`); a no-op run (nothing to release, R-SAFE-14) leaves stdout **empty** and exits `0`, mirroring R-OUT-4; without `--json`, dry-run output is byte-identical to before (the accumulator is a no-op). | ✅ shipped — `test/dry-run-json.bats` |

Schema, field reference, and the integration map live in
[`DESIGN.md`](./DESIGN.md).

Modules: `lib/effects.sh` (accumulator + emitter), `lib/args.sh` (flag,
stream discipline, guards), `verbump.sh` (emit at end of `main()`), plus one
`record-effect` call beside each `[dry-run]` preview site in `lib/hooks.sh`,
`lib/version.sh`, `lib/textbump.sh`, `lib/changelog.sh`, `lib/git-actions.sh`.
Tests: `test/dry-run-json.bats`.
