# Dry-run

`-d` / `--dry-run` previews every side effect without performing any (PRD
G2: safe-by-default).

| ID | Requirement | Status |
| --- | --- | --- |
| R-DRY-1 | No files written, no `git add/commit/tag/push/branch/checkout` executed. | ✅ shipped — `test/dryrun.bats` |
| R-DRY-2 | Every skipped side-effect printed to **stderr** with a `[dry-run]` prefix, in execution order. | ⚠️ shipped with one defect: `--undo`'s dry-run line prints to stdout (`lib/git-actions.sh`). Open bug. |
| R-DRY-3 | `--dry-run` against this repo's own checkout leaves the tree untouched (regression guard). | ✅ shipped |
| R-DRY-4 | Dry-run intercepts the push: with `-p <remote>`, no network call, no push prompt (Q-2). | ✅ shipped |

Implementation: `dryrun()` in `lib/git-actions.sh` wraps side-effecting
commands; some call sites use the standard-endorsed explicit
`if [ "$FLAG_DRYRUN" = true ]` form instead. Pre-scanned modes
(`--install-completions`, `--undo`) honour `-d` regardless of flag order.

Tests: `test/dryrun.bats`, plus `[dry-run]` assertions in `release.bats`,
`undo.bats`, `install-completions.bats`.
