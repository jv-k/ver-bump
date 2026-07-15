# ver-bump — project instructions

`ver-bump` is a single-file Bash release tool (`ver-bump.sh` + `lib/*.sh`),
tested with bats and linted with shellcheck. **The canonical coding standards
live in [`docs/CODE_STYLE.md`](docs/CODE_STYLE.md)** — read it before writing
code, commits, PRs, or issues. This file is the short entry point; that doc is
the source of truth (and it is where project conventions belong — not in any
tool's private/user-level memory).

## Stack

- **Bash 3.2+** (macOS default) — no associative arrays, no bash-4-isms.
- **git** and **jq** are the only runtime dependencies; `gh` is conditional
  (`--release` / `--pr`). Node deps are dev-only and must never be required to
  run `ver-bump.sh`.
- **pnpm**, not npm. `pnpm-lock.yaml` is canonical; a `package-lock.json` in
  the tree is a bump *target*, not this project's own lockfile. Key scripts:
  `pnpm lint` (shellcheck `-x`, must be zero warnings) and `pnpm tests:run`
  (bats, expected to pass 100%).
- Tests: bats-core under `test/`, one file per feature; requirements are
  tracked in `docs/features/*/requirements.md`.

## Commits & PRs

Full rules in [`docs/CODE_STYLE.md`](docs/CODE_STYLE.md) (§Pull requests,
§GitHub issues). The load-bearing ones:

- **Conventional Commits, scoped:** `<type>(<scope>): <subject>` — imperative,
  lowercase, no trailing period, ≤ 70 chars. Types: `feat fix refactor test
  chore docs ci`. Scopes: `ui errors config args version git-actions changelog
  json completions tests docs publish`.
- **`Refs #N.`, never `Closes #N.`** — a human closes the issue after review.
- Branches: `feat/*`, `fix/*`, `refactor/*`, `chore/*`, `docs/*`; releases use
  `release-<version>`.

### The `ralph:` scope is Sandcastle-only

The `ralph:<area>`, `ralph-review:<area>`, and `ralph-merge` scopes are
reserved for commits authored by the autonomous **Sandcastle** harness in
[`.sandcastle/`](.sandcastle/) — its prompts `git log --grep="ralph:"` to see
recent loop activity, so the marker only earns its keep on commits that harness
actually produced. **Do not use these scopes for interactive sessions or normal
contributions** (human or agent); those use the plain scopes above. If you are
not the Sandcastle loop, you are not `ralph`.
