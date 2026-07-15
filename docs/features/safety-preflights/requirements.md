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

## Remote sync (#58)

| ID | Requirement | Status | Tests |
| --- | --- | --- | --- |
| R-SAFE-5 | During Verify, if the configured remote (`PUSH_DEST`, default `origin`) exists, run `git fetch <remote> --tags --quiet`. If the fetch fails (offline, auth), **warn and continue** — air-gapped use must keep working. | ✅ `check-remote-sync` | `remote-sync.bats` |
| R-SAFE-6 | After the fetch, if the current branch has an upstream and is behind it (`git rev-list --count HEAD..@{upstream}` > 0), exit `3` with a hint (`git pull --rebase`, or `--no-fetch` to skip). | ✅ | `remote-sync.bats` |
| R-SAFE-7 | `check-tag-exists` runs **after** the fetch in `main()` ordering, so remote tags are visible to the existing local check — no second check needed. | ✅ | `remote-sync.bats` |
| R-SAFE-8 | `--no-fetch` (boolean, long-only) + `NO_FETCH` config/env key skip the network preflight explicitly. | ✅ | `remote-sync.bats`, `args.bats` |
| R-SAFE-9 | The fetch is read-only and MAY run under `--dry-run` so the preview reflects reality (same reasoning as R-REL-5's read-only notes command). | ✅ | `remote-sync.bats` |

## Release-branch guard (#59)

| ID | Requirement | Status | Tests |
| --- | --- | --- | --- |
| R-SAFE-10 | Config/env key `RELEASE_BRANCHES`: space-separated glob list (e.g. `"main develop release/*"`). Unset/empty (default) = no guard — zero behaviour change for existing users (regression-pinned). | ✅ `check-release-branch` | `release-branch-guard.bats` |
| R-SAFE-11 | When set and the current branch matches no pattern: exit `3` naming the branch and the allowed list. **Not** bypassed by `--yes` — it's a guard, not a prompt; the one-shot bypass is `RELEASE_BRANCHES= ver-bump …` (env beats rc per R-CFG-3). | ✅ | `release-branch-guard.bats` |
| R-SAFE-12 | Detached HEAD with the guard active → exit `3` (can't match a branch you're not on). | ✅ | `release-branch-guard.bats` |
| R-SAFE-13 | Applies to the release flow only; `--undo`, `--completions`, `--about`, `--help` are unaffected (they exit before the Verify section). | ✅ | `release-branch-guard.bats` |

Modules: `lib/git-checks.sh` (`check-worktree-clean`,
`check-release-branch`), `lib/args.sh`, `lib/config.sh`.
