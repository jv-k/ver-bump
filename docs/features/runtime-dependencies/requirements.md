# Runtime dependencies

The tool's pitch — "one file, plain bash, no Node ecosystem lock-in" — must
be literally true at runtime (PRD G1).

| ID | Requirement | Status |
| --- | --- | --- |
| R-DEP-1 | Runtime deps are exactly `bash`, `git`, `jq`; a clean machine with only those three succeeds. | ✅ shipped — preflight `check-dependencies` |
| R-DEP-2 | `npm`/`node` never invoked at runtime (npm install path still supported). | ✅ shipped |
| R-DEP-3 | Missing deps exit `3` with a one-line error naming the tool(s) + install hint. | ✅ shipped — `test/errors.bats` |

Notes:

- `gh` (and the `--release` notes command) are **conditional** deps, owned by
  [github-release](../github-release/requirements.md) (R-REL-4).
- Bash 3.2+ (macOS default) is the compatibility floor — see
  [ADR-03](../../ADR.md).
