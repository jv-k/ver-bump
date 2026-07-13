# Exit-code contract

Stable machine contract (PRD G4) so CI wrappers can branch on failure class.

| Code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | Generic / unexpected error |
| 2 | Usage or argument-parse error |
| 3 | Precondition failure (missing dep, no `package.json`, dirty tree, missing tag, SemVer parse, unsafe `.ver-bumprc`) |
| 4 | Hook failure — **reserved** (future hook system) |
| 5 | User abort (declined an interactive prompt) |

| ID | Requirement | Status |
| --- | --- | --- |
| R-EXIT-1 | Every user-visible error path exits with a contract code via `fail`, never bare `exit 1`. | ⚠️ shipped with known deviations (below) |
| R-EXIT-2 | Contract is versioned with the major release; must not shift between `2.x` patches. | ✅ documented here + `lib/errors.sh` |

Known deviations (open bugs):

- ESC at the version prompt exits `130` (`lib/version.sh`) instead of `5`,
  and bypasses `fail`. The push-decline path correctly uses `fail 5`.
- One `--undo` precondition path exits `3` directly after `log_warn`
  (`lib/git-actions.sh`) instead of via `fail`.

Modules: `lib/errors.sh` (`fail <code> <message> [hint]`).
Tests: `test/errors.bats` (19) — every new `fail` site needs a case here.
