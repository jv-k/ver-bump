# Release hooks

Two user-supplied hook points — `PRE_BUMP_CMD` and `POST_TAG_CMD` — around
the mutation phase of a release ([#62](https://github.com/jv-k/VerBump/issues/62)).
Deliberately minimal: a plugin system stays a non-goal (PRD §3.1). Hook
failures are the first (and only) user of exit code `4`, reserved for exactly
this since the exit-code contract landed (PRD §5.6) — the frozen 2.x contract
(R-EXIT-2) is untouched because the code's meaning was published in 2.0.0.

Closes the B-3 migration gap: 1.x users who relied on npm's `preversion`
lifecycle running their tests migrate with one `.verbumprc` line:
`PRE_BUMP_CMD="npm test"`.

| ID | Requirement | Status | Tests |
| --- | --- | --- | --- |
| R-HOOK-1 | `PRE_BUMP_CMD`: run via `bash -c` after **all** Verify preflights pass and **before any file mutation**. Non-zero → exit `4`, nothing mutated (working tree porcelain-clean, no tag, no commit). | ✅ `run-pre-bump-hook` | `hooks.bats` |
| R-HOOK-2 | `POST_TAG_CMD`: run after tag creation, before push / `--pr` / `--release`. Non-zero → exit `4`; the created commit + tag are left in place and the failure copy points at `--undo` for recovery. Skipped under `-n`/`--no-commit` (no tag was created — mirrors `do-tag`). | ✅ `run-post-tag-hook` | `hooks.bats` |
| R-HOOK-3 | Keys come from the environment or `.verbumprc` only (same trust domain — the rc is already shell-sourced behind the R-CFG-4 permission checks). Precedence per R-CFG-3 (env beats rc). No CLI flag to *set* a hook. Unset/empty = no hook, zero behaviour change (regression-pinned). | ✅ `lib/config.sh` (`_CONFIG_KEYS`) | `hooks.bats` |
| R-HOOK-4 | Hook stdout/stderr stream through to the user (not captured); the resolved command is logged before running. Under `--dry-run` the command is printed to stderr with the `[dry-run]` prefix (R-DRY-2) and **not** executed. | ✅ `_run-hook` | `hooks.bats` |
| R-HOOK-5 | `--no-hooks` (boolean, long-only) skips both — parity with git's `--no-verify` escape hatch. CLI-only, reset in `process-arguments` (R-CFG-6 pattern): an rc/env assignment must never silently disable hooks; the one-shot single-hook bypass is emptying the key (`PRE_BUMP_CMD= VerBump …`). | ✅ | `hooks.bats`, `args.bats` |
| R-HOOK-6 | Hooks receive `VERBUMP_VERSION` (new version), `VERBUMP_PREV_VERSION` (previous version), and `VERBUMP_TAG` (full tag name, `TAG_PREFIX` + version) in their environment. Exported for the child process only. Rc-defined hooks must single-quote references to these vars (the rc is shell-sourced, so double quotes expand at load time while they are still empty) — documented in the README and pinned by test. | ✅ `_run-hook` | `hooks.bats` |

Modules: `lib/hooks.sh` (`run-pre-bump-hook`, `run-post-tag-hook`,
`_run-hook`), `lib/args.sh` (`--no-hooks`), `lib/config.sh` (keys),
`lib/errors.sh` (exit-code table wording), `lib/usage.sh`,
`lib/completions.sh`.

Call sites in `main()` (`verbump.sh`): `run-pre-bump-hook` opens the Release
section — after the entire Verify section (so `process-version` has resolved
`V_NEW`/`V_PREV` and every preflight has passed) and immediately before
`do-packagefile-bump`, the first mutation. `run-post-tag-hook` sits between
`do-tag` and `do-push`, so a failing hook stops the release before anything
leaves the machine.
