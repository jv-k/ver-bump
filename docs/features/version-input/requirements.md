# Version input & validation

Every version entering the tool — via `-v`, the interactive prompt, or a
version file — is validated as SemVer 2.0 before any mutation.

| ID | Requirement | Status |
| --- | --- | --- |
| R-VER-1 | `-v <value>` / `--version <value>` rejects non-SemVer before any mutation (exit `2`). | ✅ shipped — `is_semver` (`lib/validate.sh`); `test/version.bats` |
| R-VER-2 | Interactive prompt input validated identically to `-v`. | ✅ shipped — `test/version.bats` |
| R-VER-3 | Prerelease (`-alpha.1`) and build metadata (`+sha.abc`) accepted. | ✅ shipped |

Prompt UX (shipped in 2.0, backfilled requirements):

| ID | Requirement | Status |
| --- | --- | --- |
| R-VER-4 | The version prompt pre-fills the suggestion as an editable default. | ✅ shipped (`cd87052`) |
| R-VER-5 | ESC at the prompt aborts the run with no mutation. | ⚠️ shipped, but exits `130` — the exit-code contract says user abort = `5`. Open bug; see [exit-codes](../exit-codes/requirements.md). |

Modules: `lib/version.sh`, `lib/validate.sh`. Tests: `test/version.bats` (22),
`test/versionfile.bats`, `test/bumpfile.bats`.
