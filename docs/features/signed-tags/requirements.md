# Signed tags (--sign / TAG_SIGN)

Opt-in signed release tags for provenance-conscious teams
([#68](https://github.com/jv-k/ver-bump/issues/68)): `--sign` (or
`TAG_SIGN=true`) switches `do-tag` from `git tag -a` to `git tag -s`. Key
and signing-program selection stay entirely in git's own config
(`user.signingkey`, `gpg.format`) — VerBump adds **no** key management and
no new dependency checks; git's own error output is the error surface.

| ID | Requirement | Status | Tests |
| --- | --- | --- | --- |
| R-SIGN-1 | `--sign` (boolean, long-only) and the `TAG_SIGN=true` config/env key (precedence per R-CFG-3: CLI > env > `.ver-bumprc` > default `false`): `do-tag` uses `git tag -s` instead of `-a`. Default path is unchanged (`-a`). | ✅ | `signed-tags.bats`, `args.bats` |
| R-SIGN-2 | Signing failure follows the existing tag-failure path: abort (exit 1) with git's output surfaced — the same handling that fixed the silent `git tag` failure. No gpg/ssh preflight. | ✅ | `signed-tags.bats` |
| R-SIGN-3 | `--dry-run` prints the `git tag -s …` would-run line (prefix parity with the `-a` preview), and creates nothing. | ✅ | `signed-tags.bats` |
| R-SIGN-4 | Composes with `-m`/`--message`: a custom message signs the same as the default message. | ✅ | `signed-tags.bats` |

Modules: `lib/args.sh` (parse), `lib/config.sh` (`TAG_SIGN` key + default),
`lib/git-actions.sh` (`do-tag` `-s`/`-a` switch).
Tests: `test/signed-tags.bats` (argv captured via a PATH-stubbed `git`;
precedence exercised end-to-end via the dry-run preview; plus a real
SSH-key signing round-trip that skips where the environment can't sign),
`test/args.bats` (flag parsing + `--sign=value` rejection).
