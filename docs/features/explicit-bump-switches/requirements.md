# Explicit bump switches

`--major` / `--minor` / `--patch` force the bump level for users who know
what they're releasing — no suggestion, no surprises. Shipped in 2.0
(originally PRD §13 future work; pulled forward — issue #38).

| ID | Requirement | Status |
| --- | --- | --- |
| R-FORCE-1 | `--major`/`--minor`/`--patch` force the bump level, bypassing the CC suggestion. Long-only, boolean. | ✅ shipped — `lib/args.sh` |
| R-FORCE-2 | Mutually exclusive with each other and with `-v <version>` — conflicts exit `2` naming both flags. | ✅ shipped — `test/args.bats` |
| R-FORCE-3 | `BUMP_LEVEL` is CLI-only: reset before parsing so env/`.verbumprc` can never force a level (R-CFG-6). | ✅ shipped (`783f457`) |

Modules: `lib/args.sh` (parse), `lib/version.sh` (`force-bump`).
Tests: `test/args.bats`, `test/bump-suggest.bats`.
