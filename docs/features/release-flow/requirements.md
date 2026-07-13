# Release flow (git actions)

The core mechanical sequence: bump files → changelog → release branch →
commit → annotated tag → push. Integration back to `develop`/`main` stays
human (PRD §1).

Backfilled requirements (behaviour carried from 1.x, hardened in 2.0):

| ID | Requirement | Status |
| --- | --- | --- |
| R-FLOW-1 | A `release-<version>` branch is created (prefix overridable via `-B`); `-b` skips it. | ✅ shipped — `test/git-ops.bats`, `test/prefixes.bats` |
| R-FLOW-2 | The bump commit includes every bumped file; `-n` disables commit *and* tag *and* push. | ✅ shipped |
| R-FLOW-3 | An annotated tag `<prefix><version>` is created (`-t` overrides prefix; `-m` sets the message). | ✅ shipped |
| R-FLOW-4 | `git tag` failure aborts the run with an error — never reports false success. | ✅ shipped (`5a9035a`) |
| R-FLOW-5 | Push happens only with `-p <remote>` and after interactive confirmation (`-y` auto-accepts; decline exits `5`). | ✅ shipped |
| R-FLOW-6 | Dirty-tree and zero-commit repos are rejected as preconditions (exit `3`) before any mutation. | ✅ shipped — `lib/git-checks.sh` |

Modules: `lib/git-actions.sh`, `lib/git-checks.sh`. Tests:
`test/git-ops.bats` (6), `test/prefixes.bats` (4), `test/e2e-live.bats` (2).

Related: [github-release](../github-release/requirements.md) (post-push),
[undo](../undo/requirements.md) (local revert). A tag-in-place default +
`--pr` release-PR workflow is proposed in PR #49 (unmerged) — see ADR-12.
