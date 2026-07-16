# GitHub release (--release)

Opt-in publishing of a GitHub release for the new tag, after the push.
Resolves the "automate a release" ask (issue #25, #43).

| ID | Requirement | Status |
| --- | --- | --- |
| R-REL-1 | `--release` runs `gh release create <tag> --generate-notes` (default) or `--notes "<notes>"` (custom `VER_BUMP_RELEASE_NOTES_CMD`, R-REL-2) after the tag is pushed. | ✅ shipped — `test/release.bats` (22) |
| R-REL-2 | Notes default to `gh release create --generate-notes`; a custom `VER_BUMP_RELEASE_NOTES_CMD` is captured via `--notes`. | ✅ shipped |
| R-REL-3 | `--release` requires `-p <remote>`; missing → exit `2` naming the flag. | ✅ shipped |
| R-REL-4 | `gh` is conditional: required only with `--release` (missing → `3`). `node`/`npx` only if `VER_BUMP_RELEASE_NOTES_CMD` is overridden. Default ver-bump path never invokes `gh`/`node`/`npx`. | ✅ shipped |
| R-REL-5 | Under `--dry-run`: no `gh` call; resolved invocation printed with `[dry-run]` prefix (`--generate-notes` or `--notes '<output>'`); a custom notes command may still run (read-only). | ✅ shipped |
| R-REL-6 | Notes command failing → abort before `gh`, exit `1`, stderr surfaced; tag push not rolled back. | ✅ shipped |
| R-REL-7 | Prerelease versions publish as GitHub **prereleases** (`--prerelease`). | ✅ shipped (`0c565f8`) |
| R-REL-8 | Pipeline hardened: push gate enforced, `gh auth status` preflighted, `-n` blocks release. | ✅ shipped (`93b76e4`) |
| R-REL-9 | `DO_RELEASE` is CLI-only — env/`.ver-bumprc` can never trigger a release (R-CFG-6). | ✅ shipped (`783f457`) |

Modules: `lib/args.sh` (parse), `lib/git-actions.sh` (`do-github-release`).
Tests: `test/release.bats`.
