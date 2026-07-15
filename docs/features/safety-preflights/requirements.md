# Safety preflights

Preflight guards in `main()`'s Verify section that stop a release before any
mutation when the repo state looks wrong. Safety-preflight set:
[#57](https://github.com/jv-k/ver-bump/issues/57) (dirty tree) ·
[#58](https://github.com/jv-k/ver-bump/issues/58) (remote sync) ·
[#59](https://github.com/jv-k/ver-bump/issues/59) (branch guard) ·
[#60](https://github.com/jv-k/ver-bump/issues/60) (no-op detection).

All guard failures exit `3` (precondition) via `fail` — the frozen 2.x exit
contract (R-EXIT-2) is untouched.

## Dirty working tree (#57)

| ID | Requirement | Status | Tests |
| --- | --- | --- | --- |
| R-SAFE-1 | When a commit will happen (i.e. not `-n`/`--no-commit`), a non-empty `git status --porcelain --untracked-files=no` (modified tracked files or a non-empty index) exits `3` **before any mutation**, naming the offending paths (first few + count). Untracked files are ignored. | ✅ `check-worktree-clean` | `worktree-clean.bats` |
| R-SAFE-2 | `--allow-dirty` (boolean, long-only) and the `ALLOW_DIRTY` config/env key (precedence per R-CFG-3) bypass the guard. | ✅ | `worktree-clean.bats`, `args.bats` |
| R-SAFE-3 | Under `--dry-run` the check still runs (read-only) and fails with the same exit `3`, so the preview is honest about what a real run would do. | ✅ | `worktree-clean.bats` |
| R-SAFE-4 | Skipped under `-n`/`--no-commit` (nothing is committed, nothing can be swept). | ✅ | `worktree-clean.bats` |

Modules: `lib/git-checks.sh` (`check-worktree-clean`), `lib/args.sh`,
`lib/config.sh`.
