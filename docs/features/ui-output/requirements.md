# UI & output

A structured log vocabulary, semantic colour tokens, and branded blocks —
trust through legibility (PRD G2/G4). The discipline is locked in by
regression tests.

Backfilled requirements:

| ID | Requirement | Status |
| --- | --- | --- |
| R-UI-1 | All status output goes through `log_*` helpers with the symbol vocabulary (`I_*`); section headers use inverse-video pills. | ✅ shipped (`110734d`, `ef2903f`, `051b46d`) |
| R-UI-2 | Colour is semantic (`S_*` tokens only; raw colour vars never leave `lib/styles.sh`); narrative text carries no colour; values use `S_VAL`. | ✅ shipped — `test/ui.bats` |
| R-UI-3 | Colour gating: `NO_COLOR` off, `CLICOLOR_FORCE`/`FORCE_COLOR` force-on, non-TTY off. | ✅ shipped — `test/color.bats` |
| R-UI-4 | `--about` prints a branded block (name, version, author, homepage) and exits 0 anywhere. | ✅ shipped — `test/about.bats` |
| R-UI-5 | Errors (via `fail`) go to stderr with an optional self-service hint; pipeable output (completions, `--help`) stays clean on stdout. | ✅ shipped |

Modules: `lib/ui.sh`, `lib/styles.sh`, `lib/icons.sh`, `lib/usage.sh`.
Tests: `test/ui.bats`, `test/color.bats`, `test/about.bats`.

Style rules for contributors live in `docs/CODE_STYLE.md` (UI / colour
discipline) — changes here require updating `ui.bats`.
