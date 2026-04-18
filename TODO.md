# ver-bump

📦 A handy utility that takes care of releasing Git software projects

## Now ⏳

- [ ] tests: bats coverage for `bump-prerelease`, `is_semver`, `normalize-long-opts`, and `--dry-run` behaviour
- [ ] docs: README section for new flags (`-d`, `-t`, `-B`, all `--long` forms); audit `-n` wording for the new "disable commit + tag + push" semantics

## Next 🚀

- [ ] feat: `--major` / `--minor` / `--patch` bump switches
- [ ] feat: auto-create GitHub Release from the tag ver-bump produces

## Someday / maybe 💭

- [ ] distribute via [basher](https://github.com/basherpm/basher) — decide: replace NPM or ship alongside
- [ ] docs: how to publish to GitHub Packages (what the `publish-github` job needs)

## Done ✔️

- [x] feat: long-form options (`--version`, `--message`, `--file`, `--push`, `--tag-prefix`, `--branch-prefix`, `--dry-run`)
- [x] feat: `--dry-run` mode
- [x] feat: SemVer 2.0 validation of `-v` input via `is_semver`
- [x] feat: prerelease version bumping (`1.2.3-dev.6` → `1.2.3-dev.7`) via `bump-prerelease`
- [x] feat: overridable tag (`-t`) and branch (`-B`) prefixes
- [x] fix: `do-push` now pushes the release branch alongside the tag; exit-code check corrected
- [x] fix: `do-changelog` commit range `..HEAD` (was `...HEAD`)
- [x] fix: `bump-json-files` no longer overwrites source file on `jq` failure
- [x] fix: `do-tag` skipped when `-n` is set (no more tags pointing at pre-bump HEAD)
- [x] refactor: JSON parsing via `jq` throughout (was regex `sed`)
- [x] chore: preflight check for `git` / `jq`
- [x] chore: CI upgraded to `actions/checkout@v4`, `setup-node@v4`, Node 20, scoped `permissions`
- [x] docs: Create GIF screenshot
- [x] feat: switch to disable pause during CHANGELOG.md creation
- [x] tests: unit tests with [bats-core](https://github.com/bats-core/bats-core)
- [x] fix: running on `v1.0.0` (or any version present in `package.json` but not tagged)
- [x] docs: inform user how the script works in the current branch
- [x] docs: local `npm` install
- [x] docs: SemVer + Gh branching model
- [x] docs: document all remaining switches
