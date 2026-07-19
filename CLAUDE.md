# VerBump — project instructions

`VerBump` is a plain-bash release tool (`verbump.sh` + `lib/*.sh`),
tested with bats and linted with shellcheck. **The canonical coding standards
live in [`docs/CODE_STYLE.md`](docs/CODE_STYLE.md)** — read it before writing
code, commits, PRs, or issues. This file is the short entry point; that doc is
the source of truth (and it is where project conventions belong — not in any
tool's private/user-level memory).

## Stack

- **Bash 3.2+** (macOS default) — no associative arrays, no bash-4-isms.
- **git** and **jq** are the only runtime dependencies; `gh` is conditional
  (`--release` / `--pr`). Node deps are dev-only and must never be required to
  run `verbump.sh`.
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

## Agent skills

### Issue tracker

Issues and PRDs are tracked as **GitHub issues** via the `gh` CLI
(`github.com/jv-k/VerBump`). See
[`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).

### Triage labels

The five canonical triage roles map **1:1** onto identically-named GitHub
labels already in the repo. See
[`docs/agents/triage-labels.md`](docs/agents/triage-labels.md).

### Domain docs

**Single-context.** ADRs live in a single `docs/ADR.md` (`ADR-NN` sections),
alongside `docs/PRD.md` and `docs/features/*/requirements.md`; `docs/CONTEXT.md`
is created lazily. See [`docs/agents/domain.md`](docs/agents/domain.md).
