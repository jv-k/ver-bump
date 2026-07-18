# Contributing to VerBump

Thanks for helping! This is the short version — the canonical coding
standards, commit conventions, and test requirements live in
[`docs/CODE_STYLE.md`](docs/CODE_STYLE.md). When the two disagree, that doc
wins.

## Found a bug? Want a feature?

Open an [issue](https://github.com/jv-k/VerBump/issues/new/choose).

## Working on the code

The tool targets **Bash 3.2+** (no associative arrays, no bash-4-isms) and
must run with only `git` and `jq` installed — Node and pnpm are dev-only.

```sh
pnpm install         # dev toolchain
pnpm lint            # shellcheck — must exit with zero warnings
pnpm tests:install   # one-time: vendors bats-core + helpers
pnpm tests:run       # bats suite — must pass 100%
pnpm dev             # exercise your change in a throwaway sandbox repo
```

`pnpm dev` runs VerBump inside a temp git repo seeded with conventional
commits, so you never dirty a real repo — see the README's
[Development](README.md#development) section.

## Branches, commits, PRs

- Branch names match the change type: `feat/*`, `fix/*`, `refactor/*`,
  `chore/*`, `docs/*`.
- Commit and PR titles are Conventional Commits with a scope:
  `<type>(<scope>): <subject>` — imperative, lowercase, ≤ 70 chars.
- PR bodies follow the structure in
  [`docs/CODE_STYLE.md` § Pull requests](docs/CODE_STYLE.md#pull-requests):
  summary paragraph, bullets of concrete changes, behavioural notes, tests.
- Reference the issue with `Refs #N.` — maintainers close issues after
  review, so don't use `Closes`.
- Keep each PR scoped to one concern.
