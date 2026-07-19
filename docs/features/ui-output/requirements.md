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

## Quiet mode (`-q` / `--quiet`) — machine-readable stdout

The missing half of the machine contract R-EXIT started (issue #65):
`NEW_VERSION=$(verbump --yes --quiet -p origin)` is the canonical CI
capture pattern.

| ID | Requirement | Status |
| --- | --- | --- |
| R-OUT-1 | `-q`/`--quiet`: decorative output is routed off stdout; on success stdout carries exactly one line — the new version, no tag prefix, no colour codes. Errors keep going to stderr with the contract exit codes. | ✅ shipped — `test/quiet.bats` |
| R-OUT-2 | `--quiet` and interactive prompts are incompatible by construction (a hidden prompt is a hung pipeline): `--quiet` without `--yes`, `-v`, a forced bump level, or `--preid` exits `2` naming the fix; `--quiet` with `-l`/`--pause-changelog` (flag or rc key) exits `2`; `--quiet --undo` without `--yes` exits `2`. | ✅ shipped — `test/quiet.bats`, `test/preid.bats` |
| R-OUT-3 | Composes with `--dry-run`: stdout gets the would-be version; the `[dry-run]` side-effect lines target stderr (R-DRY-2), so the pipe stays clean. | ✅ shipped — `test/quiet.bats` |
| R-OUT-4 | A quiet no-op (nothing to release, R-SAFE-14) prints **nothing** on stdout — the `no-release` token is rerouted with the rest of the decoration — and exits `0`, so `[ -z "$out" ]` is the CI branch test for "no release happened". | ✅ shipped — `test/quiet.bats` |

The bucket continues in
[dry-run-json](../dry-run-json/requirements.md): R-OUT-5..7 cover
`--dry-run --json`, the structured release *plan* on the same FD-3 channel.

Implementation is stream discipline, not a renderer: `process-arguments`
(`lib/args.sh`) pre-scans argv for `-q`/`--quiet`, saves the real stdout on
FD 3 and redirects FD 1 to stderr (`exec 3>&1 1>&2`) before any option echo
runs; `main()` (`verbump.sh`) prints the bare version to FD 3 as its last
step. One redirect beats guarding every `log_*`/`echo` call site — nothing
can leak into the captured pipeline, and warnings/prompts stay visible on
stderr. `--undo` handles quiet in its own pre-scan (no version to report,
so quiet stdout stays completely empty). `FLAG_QUIET` is CLI-only — reset
in `process-arguments` like `BUMP_LEVEL`/`ALLOW_EMPTY`, never a
`.verbumprc` key: hidden-output mode must be an explicit per-invocation
choice (same rationale as `FLAG_YES`, R-YES-3).

Modules: `lib/ui.sh`, `lib/styles.sh`, `lib/icons.sh`, `lib/usage.sh`;
quiet mode: `lib/args.sh`, `verbump.sh`.
Tests: `test/ui.bats`, `test/color.bats`, `test/about.bats`,
`test/quiet.bats`.

Style rules for contributors live in `docs/CODE_STYLE.md` (UI / colour
discipline) — changes here require updating `ui.bats`.
