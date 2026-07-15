# Prerelease entry

`R-BUMP-1` iterates an existing prerelease nicely (`4.0.0-dev.6` →
`dev.7`), but there was no switch to **enter** one — `1.2.3` → `2.0.0-rc.1`
required a hand-typed `-v`. `--preid <id>` closes that gap, composing with
the existing `--major`/`--minor`/`--patch` switches rather than adding four
npm-style `pre*` subcommand flags (issue #64).

| ID | Requirement | Status |
| --- | --- | --- |
| R-PRE-1 | `--preid <id>` with a level switch (`--major`/`--minor`/`--patch`): bump that level, then append `-<id>.1`. Example: `1.2.3` + `--major --preid rc` → `2.0.0-rc.1`. | ✅ shipped — `lib/version.sh` |
| R-PRE-2 | `--preid <id>` alone on a version that already has a prerelease: same id → increment the counter (the R-BUMP-1 path, via `bump-prerelease`); different id → swap the id and reset the counter to `.1`. Example: `2.0.0-alpha.3` + `--preid rc` → `2.0.0-rc.1`. | ✅ shipped — `bump-preid`, `lib/validate.sh` |
| R-PRE-3 | `--preid` alone on a **stable** version → exit `2` (ambiguous bump level; message names `--major`/`--minor`/`--patch`). | ✅ shipped — `lib/version.sh` |
| R-PRE-4 | Conflicts with `-v <version>` → exit `2`, order-independent (extends the R-FORCE-2 mutual-exclusion matrix). | ✅ shipped — `lib/args.sh` |
| R-PRE-5 | `<id>` is validated against the SemVer prerelease grammar (dot-separated alphanumeric/hyphen identifiers, no leading-zero numeric parts) at parse time, before any mutation. | ✅ shipped — `is_prerelease_id`, `lib/validate.sh` |
| R-PRE-6 | Graduating out of a prerelease is unchanged: interactive prompt or `-v 2.0.0`. `--major`/`--minor`/`--patch` **without** `--preid` on a prerelease version bumps from the stable core (documented in `--help` and the README). | ✅ shipped (pre-existing `force-bump` behaviour) — `lib/usage.sh` |

`PRE_ID` is CLI-only (reset in `process-arguments`, same rationale as
`BUMP_LEVEL` — R-CFG-6): no env / `.ver-bumprc` contract.

Modules: `lib/args.sh` (parse + validate + `-v` conflict), `lib/version.sh`
(`process-version` composition), `lib/validate.sh` (`is_prerelease_id`,
`bump-preid`), `lib/usage.sh` / `lib/completions.sh` / `README.md` (surface
parity).

Tests: `test/args.bats` (flag parsing), `test/preid.bats` (composition +
semantics, unit and end-to-end).
