# Changelog

CHANGELOG.md update as part of the release flow. Two styles as of #61:
the default `flat` git-log dump — byte-identical to 1.x, and staying the
default for all of 2.x (flipping it is a 3.0 decision) — and the opt-in
`CHANGELOG_STYLE=grouped` Conventional-Commit sections with commit/PR/
compare links.

Backfilled requirements (behaviour carried from 1.x, stabilized in 2.0):

| ID | Requirement | Status |
| --- | --- | --- |
| R-LOG-1 | A `CHANGELOG.md` section is prepended for the new version, listing commits since the previous tag. | ✅ shipped — `test/changelog.bats` |
| R-LOG-2 | `-c` / `--no-changelog` skips the update entirely. | ✅ shipped |
| R-LOG-3 | `-l` / `--pause-changelog` pauses before the commit so the user can hand-edit the generated section. | ✅ shipped |
| R-LOG-4 | Changelog writing honours dry-run (R-DRY-1/2). | ✅ shipped |

Grouped changelog (issue #61):

| ID | Requirement | Status |
| --- | --- | --- |
| R-CHLOG-1 | Opt-in via `CHANGELOG_STYLE=grouped` — a config/env key only (R-CFG-2/3 precedence), no CLI flag. Default remains `flat` and byte-identical to the legacy output; any other value behaves as flat. | ✅ shipped — `test/changelog-grouped.bats` (precedence trio), `test/changelog.bats` (flat byte-identity pin), `test/config.bats` (key round-trip, default) |
| R-CHLOG-2 | Sections in fixed order: Breaking Changes (`<type>!:` subject or `BREAKING CHANGE:` footer), Features (`feat`), Fixes (`fix`), Other (everything else *including* non-conventional messages — nothing is ever dropped). Each commit lands in exactly one section (breaking wins). Scopes render as a bold `**scope:**` prefix; a parsed `type(scope):` prefix is stripped (the heading carries the type); non-conventional subjects render verbatim. Empty sections are omitted. | ✅ shipped — `test/changelog-grouped.bats` (full snapshot, footer routing, empty-section omission, `classify-commit` table) |
| R-CHLOG-3 | Each entry links its short SHA to the commit as explicit markdown; `(#N)` PR refs stay verbatim (GitHub auto-links them when rendered); the version heading links the `prev...new` compare view when a previous tag exists. | ✅ shipped — `test/changelog-grouped.bats` (HTTPS/SSH link tests, no-tag heading test) |
| R-CHLOG-4 | Forge base URL derived from `git remote get-url` (`PUSH_DEST`, falling back to `origin`), handling GitHub SSH (`git@github.com:o/r.git`, `ssh://`) and HTTPS forms. Non-GitHub remote or no remote → plain-text entries, no links, never a failure. | ✅ shipped — `test/changelog-grouped.bats` (`_forge-base-url` table, non-GitHub + no-remote snapshots) |
| R-CHLOG-5 | Prepend-to-existing-file behaviour and the `-c` / `-l` flag semantics are unchanged in both styles; dry-run parity holds; the tool's own bump commit keeps its manual entry (classified like any commit, no SHA link since the commit happens after the write). | ✅ shipped — `test/changelog-grouped.bats` (prepend, `-c`, `-l`, dry-run) |

Modules: `lib/changelog.sh` (rendering, `_forge-base-url`), `lib/version.sh`
(`classify-commit`, shared with the R-BUMP-2 bump suggestion so the parsing
rules can't drift), `lib/config.sh` (`CHANGELOG_STYLE` key + default).
Tests: `test/changelog.bats`, `test/changelog-grouped.bats`.
