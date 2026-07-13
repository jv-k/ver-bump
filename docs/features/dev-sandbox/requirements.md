# Dev sandbox

Contributors exercise the real release flow (not just dry-run) in an
isolated throwaway repo (PRD G5, US-6).

| ID | Requirement | Status |
| --- | --- | --- |
| R-DEV-1 | `pnpm dev` / `./dev/sandbox.sh` creates an isolated throwaway git repo, runs `ver-bump` inside it, cleans up on exit incl. Ctrl-C. | ✅ `test/sandbox.bats` |
| R-DEV-2 | Sandbox cleanup must never fire against the host repo. | ✅ `test/sandbox.bats` |
| R-DEV-3 | `SANDBOX_VERSION` / `SANDBOX_COMMITS` customise start state; `--keep`/`-k` preserves the temp dir. | ✅ `test/sandbox.bats` |

Coverage notes: cleanup is exercised on normal exit, on ver-bump failure
(exit code propagation), and on SIGTERM delivered mid-run to the sandbox and
its foreground `ver-bump` child — the closest deterministic analogue to
Ctrl-C from a non-interactive test (a real Ctrl-C signals the whole
foreground process group; bash defers traps until the foreground child
exits, so both processes are signalled explicitly).

Also in `dev/` (unspecced tooling, no requirements): `screenshots.sh` +
`capture-freeze.sh` (deterministic README panels), `prepublish-version-guard.sh`,
VHS tapes for the demo GIF.

Modules: `dev/sandbox.sh`.
