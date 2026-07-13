# GitHub release (--release)

Opt-in publishing of a GitHub release for the new tag, after the push.
Resolves the "automate a release" ask (issue #25, #43).

| ID | Requirement | Status |
| --- | --- | --- |
| R-REL-1 | `--release` runs `gh release create <tag> --notes "<notes>"` after the tag is pushed. | ✅ shipped — `test/release.bats` (20) |
| R-REL-2 | Notes come from `VER_BUMP_RELEASE_NOTES_CMD` stdout (default `npx jv-k/releasetool`). | ✅ shipped |
| R-REL-3 | `--release` requires `-p <remote>`; missing → exit `2` naming the flag. | ✅ shipped |
| R-REL-4 | `gh` + notes-command deps are conditional: required only with `--release` (missing → `3`); default path never invokes `gh`/`node`/`npx`. | ✅ shipped |
| R-REL-5 | Under `--dry-run`: no `gh` call; resolved invocation printed to stderr with `[dry-run]` prefix; notes command may still run (read-only). | ✅ shipped |
| R-REL-6 | Notes command failing → abort before `gh`, exit `1`, stderr surfaced; tag push not rolled back. | ✅ shipped |
| R-REL-7 | Prerelease versions publish as GitHub **prereleases** (`--prerelease`). | ✅ shipped (`0c565f8`) |
| R-REL-8 | Pipeline hardened: push gate enforced, `gh auth status` preflighted, `-n` blocks release. | ✅ shipped (`93b76e4`) |
| R-REL-9 | `DO_RELEASE` is CLI-only — env/`.ver-bumprc` can never trigger a release (R-CFG-6). | ✅ shipped (`783f457`) |

Modules: `lib/args.sh` (parse), `lib/git-actions.sh` (`do-github-release`).
Tests: `test/release.bats`.
