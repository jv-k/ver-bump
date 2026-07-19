# Curl installer (install.sh)

Checksummed, no-Node install path built on GitHub release assets. Closes the
gap between the "pure bash" pitch and the npm-only install (issue #66);
complements the tracked Homebrew (#24) and basher (#39) paths.

| ID | Requirement | Status |
| --- | --- | --- |
| R-DIST-1 | `install.sh` at the repo root downloads the latest GitHub release tarball (or a pinned one via `VERBUMP_INSTALL_VERSION=x.y.z` / `--version`), verifies its published sha256, and unpacks `verbump.sh` + `lib/` under `${VERBUMP_PREFIX:-$HOME/.local}` (`share/verbump/` + a `bin/VerBump` symlink). | ✅ shipped — `test/install.bats` |
| R-DIST-2 | The release workflow publishes `verbump.tar.gz` + `verbump.tar.gz.sha256` as release assets (`publish-release-assets` job in `ci.yml`, extends the existing publish CI). | ✅ shipped — smoke step installs from the freshly published release and runs `--about` |
| R-DIST-3 | Installer needs only `bash`, `curl` (or `wget`), `tar`, and `sha256sum`/`shasum`; it is idempotent (re-run upgrades in place), prints the installed version, and suggests `verbump --install-completions`. | ✅ shipped — `test/install.bats` |
| R-DIST-4 | README install section leads with the one-liner, with the pipe-to-shell caveat and the download-then-inspect alternative spelled out honestly. | ✅ shipped — README `Installation` |
| R-DIST-5 | Checksum mismatch or download failure → non-zero exit, nothing installed, partial files cleaned up. | ✅ shipped — negative cases in `test/install.bats` |

Design notes:

- Assets use **unversioned names** so both URL forms stay static — no API
  calls, no JSON parsing, no redirect scraping, identical behaviour under
  `curl` and `wget`:
  - latest: `releases/latest/download/verbump.tar.gz`
  - pinned: `releases/download/v<x.y.z>/verbump.tar.gz`
- The tarball carries `package.json` in addition to the runtime set
  (`verbump.sh`, `lib/`, `LICENSE`) because `--about` / `--help` read the
  tool's name + version from it (`version_block` in `lib/ui.sh`).
- `install.sh` is standalone by design — it must not source `lib/` (nothing
  is installed yet when it runs). `is_semver` and the exit-code contract
  (2 usage / 3 missing tools / 1 failure) are mirrored from `lib/`.
- `http_fetch` is the single network seam; tests stub it to serve local
  fixture files, so the bats suite never touches the network.
- Install is a rename swap with rollback: the verified tree is staged next
  to `share/verbump` (same filesystem, so the swap is a plain rename), any
  previous install is moved aside — not deleted — and only removed once the
  new tree and symlink are in place. A failure mid-swap restores the
  previous install; a backup that cannot be restored is preserved and named,
  never deleted.

Modules: `install.sh` (standalone), `publish-release-assets` in
[.github/workflows/ci.yml](../../../.github/workflows/ci.yml).
Tests: `test/install.bats`.
