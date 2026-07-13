# Changelog

CHANGELOG.md update as part of the release flow. Deliberately simple in
2.0: the `git log` dump format is preserved as-is (PRD §3.1 non-goal — a
grouped, Conventional-Commit-aware changelog is post-2.0 future work).

Backfilled requirements (behaviour carried from 1.x, stabilized in 2.0):

| ID | Requirement | Status |
| --- | --- | --- |
| R-LOG-1 | A `CHANGELOG.md` section is prepended for the new version, listing commits since the previous tag. | ✅ shipped — `test/changelog.bats` |
| R-LOG-2 | `-c` / `--no-changelog` skips the update entirely. | ✅ shipped |
| R-LOG-3 | `-l` / `--pause-changelog` pauses before the commit so the user can hand-edit the generated section. | ✅ shipped |
| R-LOG-4 | Changelog writing honours dry-run (R-DRY-1/2). | ✅ shipped |

Modules: `lib/changelog.sh`. Tests: `test/changelog.bats`.

Future: grouped changelog from Conventional Commits — PRD §13.
