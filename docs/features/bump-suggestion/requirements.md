# Bump suggestion

The suggested next version is derived from Conventional Commits (or the
prerelease counter), so pressing Enter does the right thing.

| ID | Requirement | Status |
| --- | --- | --- |
| R-BUMP-1 | Prerelease versions increment the trailing numeric counter (or append `.1`); build metadata preserved. | ✅ shipped — `bump-prerelease` |
| R-BUMP-2 | Otherwise Conventional Commits since the last tag decide: `<type>!:`/`BREAKING CHANGE:` → major; `feat:` → minor; else patch. | ✅ shipped — `suggest-bump-level` |
| R-BUMP-3 | No previous tag → fall back to patch; never produce invalid SemVer. | ✅ shipped |
| R-BUMP-4 | The chosen bump level is printed before the prompt — never silent. | ✅ shipped |
| R-BUMP-5 | Forced (`--major/--minor/--patch`) or explicit (`-v`) versions skip the suggestion machinery entirely. | ✅ shipped (`2571944`) |

Parser discipline: subject-vs-body splitting uses RS/US separators so
`BREAKING CHANGE:` quoted in a body line never triggers a major bump — see
`docs/CODE_STYLE.md` (Data-flow conventions).

Modules: `lib/version.sh`. Tests: `test/bump-suggest.bats` (12).
