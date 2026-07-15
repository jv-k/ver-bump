# Version source (`--source` + git-tag fallback)

`package.json` is only the *default* version source. `--source <file.json>`
(or the `SOURCE_FILE` config/env key) points the source — and the primary
bump target — at any JSON file, and when the source file does not exist the
current version is derived from the latest matching release tag. Non-Node
repos get the full bump-suggestion machinery without a dummy `package.json`
or a `-v` on every run. Backfilled from issue
[#63](https://github.com/jv-k/ver-bump/issues/63) (post-PRD, per the
[features index](../README.md) convention).

| ID | Requirement | Status |
| --- | --- | --- |
| R-SRC-1 | `--source <file.json>` (long-only, takes arg) replaces `package.json` as the version source **and** primary bump target. The built-in `package-lock.json` companion bump (R-OPT-7) applies only when the source is actually `package.json`. | ✅ — `lib/args.sh`, `lib/version.sh::do-packagefile-bump`; `test/version-source.bats` |
| R-SRC-2 | When the source file is absent: `V_PREV` derives from `git describe --tags --abbrev=0 --match "${TAG_PREFIX}[0-9]*"`, `TAG_PREFIX` stripped, validated as SemVer. The full suggestion machinery (R-BUMP-1..4) then works unchanged. | ✅ — `lib/version.sh::process-version`; `test/version-source.bats` |
| R-SRC-3 | Tag-derived mode has no source file to write: the release consists of `-f` extras (if any) + CHANGELOG + commit + tag. When nothing is staged, the commit is skipped and the tag lands on the current HEAD (a tag-only release is valid output). | ✅ — `lib/git-actions.sh::do-commit`; `test/version-source.bats` |
| R-SRC-4 | No tags **and** no source file → exit `3`, with a hint naming both escape routes (`-v <version>` for the first release, or create the file). | ✅ — `lib/version.sh::process-version`; `test/version-source.bats`, `test/errors.bats` |
| R-SRC-5 | `SOURCE_FILE` config/env key mirrors the flag (R-CFG-3 precedence: CLI `--source` > env > `.ver-bumprc` > `package.json` default). | ✅ — `lib/config.sh`; `test/version-source.bats` |

Notes:

- A tag-derived `V_PREV` by definition has a matching tag, so the
  nothing-to-release no-op guard (R-SAFE-14..18) applies to source-less
  repos exactly as it does to `package.json` ones; `--allow-empty` remains
  the override.
- Completions restrict `--source` to `*.json` (same rule as `-f`,
  R-COMP-3) in all three emitters.

Modules: `lib/version.sh`, `lib/args.sh`, `lib/config.sh`,
`lib/git-actions.sh`, `lib/completions.sh`. Tests:
`test/version-source.bats`, `test/args.bats`.
