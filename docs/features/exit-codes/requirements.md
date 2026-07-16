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
| R-EXIT-1 | Every user-visible error path exits with a contract code via `fail`, never bare `exit 1`. | ✅ shipped — ESC at the version prompt and the `--undo` remote-artefacts precondition now exit via `fail` (`5` and `3`) |
| R-EXIT-2 | Contract is versioned with the major release; must not shift between `2.x` patches. | ✅ documented here + `lib/errors.sh` |

Modules: `lib/errors.sh` (`fail <code> <message> [hint]`).
Tests: `test/errors.bats` (21) — every new `fail` site needs a case here.
