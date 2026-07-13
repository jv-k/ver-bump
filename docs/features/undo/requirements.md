# Local undo (--undo)

Revert a just-cut release locally — branch, tag, bump commit — before
anything is pushed. Never touches a remote.

| ID | Requirement | Status |
| --- | --- | --- |
| R-UNDO-1 | `--undo [version]` deletes the release branch + tag for `<version>` (default: current `package.json` version) and reverts the bump commit when it is `HEAD`. Local only. | ✅ shipped (`f8d65ea`) — `test/undo.bats` (12) |
| R-UNDO-2 | Honours `--dry-run`, `--yes`, `--tag-prefix`, `--branch-prefix` regardless of position in argv; worktree marker respected (`d32d426`). | ✅ shipped |
| R-UNDO-3 | Prompts for confirmation before deleting; `-y` bypasses. | ✅ shipped |
| R-UNDO-4 | Precondition refusals and aborts use contract exit codes via `fail`. | ⚠️ mostly — one path exits `3` directly after `log_warn` instead of via `fail`; and the dry-run preview line prints to **stdout**, violating R-DRY-2. Open bugs. |

Modules: `lib/args.sh` (pre-scan), `lib/git-actions.sh` (`do-undo`).
Tests: `test/undo.bats`.
