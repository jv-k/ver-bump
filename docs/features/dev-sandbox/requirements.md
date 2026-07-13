# Dev sandbox

Contributors exercise the real release flow (not just dry-run) in an
isolated throwaway repo (PRD G5, US-6).

| ID | Requirement | Status |
| --- | --- | --- |
| R-DEV-1 | `pnpm dev` / `./dev/sandbox.sh` creates an isolated throwaway git repo, runs `ver-bump` inside it, cleans up on exit incl. Ctrl-C. | ⚠️ shipped, **untested** |
| R-DEV-2 | Sandbox cleanup must never fire against the host repo. | ⚠️ shipped, **untested** |
| R-DEV-3 | `SANDBOX_VERSION` / `SANDBOX_COMMITS` customise start state; `--keep`/`-k` preserves the temp dir. | ⚠️ shipped, **untested** |

**Known gap (AC-1 violation):** `test/dev-tests.bats` was deleted during the
test-suite reorganisation and no current test references `dev/sandbox.sh`.
R-DEV-1..3 are the only PRD requirements with zero bats coverage.

Also in `dev/` (unspecced tooling, no requirements): `screenshots.sh` +
`capture-freeze.sh` (deterministic README panels), `prepublish-version-guard.sh`,
VHS tapes for the demo GIF.

Modules: `dev/sandbox.sh`.
