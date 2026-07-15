# Curl installer (install.sh)

Checksummed, no-Node install path built on GitHub release assets. Closes the
gap between the "pure bash" pitch and the npm-only install (issue #66);
complements the tracked Homebrew (#24) and basher (#39) paths.

| ID | Requirement | Status |
| --- | --- | --- |
| R-DIST-1 | `install.sh` at the repo root downloads the latest GitHub release tarball (or a pinned one via `VER_BUMP_INSTALL_VERSION=x.y.z` / `--version`), verifies its published sha256, and unpacks `ver-bump.sh` + `lib/` under `${VER_BUMP_PREFIX:-$HOME/.local}` (`share/ver-bump/` + a `bin/ver-bump` symlink). | ✅ shipped — `test/install.bats` |
| R-DIST-2 | The release workflow publishes `ver-bump.tar.gz` + `ver-bump.tar.gz.sha256` as release assets (`publish-release-assets` job in `ci.yml`, extends the existing publish CI). | ✅ shipped — smoke step installs from the freshly published release and runs `--about` |
| R-DIST-3 | Installer needs only `bash`, `curl` (or `wget`), `tar`, and `sha256sum`/`shasum`; it is idempotent (re-run upgrades in place), prints the installed version, and suggests `ver-bump --install-completions`. | ✅ shipped — `test/install.bats` |
| R-DIST-4 | README install section leads with the one-liner, with the pipe-to-shell caveat and the download-then-inspect alternative spelled out honestly. | ✅ shipped — README `Installation` |
| R-DIST-5 | Checksum mismatch or download failure → non-zero exit, nothing installed, partial files cleaned up. | ✅ shipped — negative cases in `test/install.bats` |

Design notes:

- Assets use **unversioned names** so both URL forms stay static — no API
  calls, no JSON parsing, no redirect scraping, identical behaviour under
  `curl` and `wget`:
  - latest: `releases/latest/download/ver-bump.tar.gz`
  - pinned: `releases/download/v<x.y.z>/ver-bump.tar.gz`
- The tarball carries `package.json` in addition to the runtime set
  (`ver-bump.sh`, `lib/`, `LICENSE`) because `--about` / `--help` read the
  tool's name + version from it (`version_block` in `lib/ui.sh`).
- `install.sh` is standalone by design — it must not source `lib/` (nothing
  is installed yet when it runs). `is_semver` and the exit-code contract
  (2 usage / 3 missing tools / 1 failure) are mirrored from `lib/`.
- `http_fetch` is the single network seam; tests stub it to serve local
  fixture files, so the bats suite never touches the network.
- Install is stage-then-swap: the verified tree is staged next to
  `share/ver-bump` and swapped in only after every earlier step succeeded,
  so a failed run can never leave a half-written install.

Modules: `install.sh` (standalone), `publish-release-assets` in
[.github/workflows/ci.yml](../../../.github/workflows/ci.yml).
Tests: `test/install.bats`.
