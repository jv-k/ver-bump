#!/bin/bash
#
# install.sh — checksummed installer for VerBump (issue #66, R-DIST-1..5).
#
# Downloads a GitHub release tarball, verifies its published sha256, and
# installs under ${VER_BUMP_PREFIX:-$HOME/.local}:
#
#   <prefix>/share/ver-bump/   the release tree (ver-bump.sh + lib/ + …)
#   <prefix>/bin/VerBump      symlink to share/ver-bump/ver-bump.sh
#
# Designed to be piped —
#
#   curl -fsSL https://raw.githubusercontent.com/jv-k/ver-bump/main/install.sh | bash
#
# so it is deliberately boring: no colour, no dependencies beyond bash + tar
# + (curl|wget) + (sha256sum|shasum), and all real work happens inside main()
# on the last line, so a truncated download can never half-execute.
#
# Failure contract (R-DIST-5): any download, checksum, or install error exits
# non-zero, keeps (or restores) any existing install, and cleans up temp
# files. Exit codes mirror lib/errors.sh: 2 usage, 3 missing tools, 1 else.

REPO_SLUG="jv-k/ver-bump"
ASSET_NAME="ver-bump.tar.gz"

# Set by parse-args / install-paths; documented here as the integration
# surface between steps (the repo's globals-between-phases convention).
INSTALL_VERSION=""   # empty = latest stable release
INSTALL_PREFIX=""
SHARE_DIR=""
BIN_DIR=""
BIN_LINK=""
WORK_DIR=""          # mktemp scratch dir, removed by the EXIT trap
STAGED_DIR=""        # in-flight ${SHARE_DIR}.staged.$$, removed by the trap
BACKUP_DIR=""        # previous install moved aside during the swap; removed
                     # on success, restored (never deleted) on failure

usage() {
  cat <<'EOF'
VerBump installer — download a release, verify its sha256, install it.

Usage:
  curl -fsSL https://raw.githubusercontent.com/jv-k/ver-bump/main/install.sh | bash
  bash install.sh [--version <x.y.z>] [--prefix <dir>]

Options:
  --version <x.y.z>   Install a specific release (default: latest stable).
  --prefix <dir>      Install prefix (default: ~/.local).
  -h, --help          Show this help.

Environment:
  VER_BUMP_INSTALL_VERSION   Same as --version (a flag wins over the env var).
  VER_BUMP_PREFIX            Same as --prefix.

Layout:
  <prefix>/share/ver-bump/   the release tree (ver-bump.sh + lib/)
  <prefix>/bin/VerBump      symlink to share/ver-bump/ver-bump.sh

Re-running upgrades an existing install in place.
EOF
}

# bail <code> <message> [hint] — error to stderr, then exit <code>. Mirrors
# fail() in lib/errors.sh without depending on it: the installer runs before
# anything is installed, so it must stay self-contained.
bail() {
  local code=$1
  printf 'VerBump install: error: %s\n' "$2" >&2
  if [ -n "${3:-}" ]; then
    printf '  hint: %s\n' "$3" >&2
  fi
  exit "$code"
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# Keep in sync with is_semver in lib/validate.sh (copied, not sourced: the
# installer must work before lib/ exists on the machine).
is_semver() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$ ]]
}

# R-DIST-3: bash + tar + (curl|wget) + (sha256sum|shasum) is the entire
# dependency surface. git/jq are VerBump *runtime* deps — the tool checks
# those itself on first run, deliberately not here.
check-install-deps() {
  local missing=()
  have_cmd tar || missing+=("tar")
  have_cmd curl || have_cmd wget || missing+=("curl (or wget)")
  have_cmd sha256sum || have_cmd shasum || missing+=("sha256sum (or shasum)")
  [ ${#missing[@]} -eq 0 ] || \
    bail 3 "missing required tools: ${missing[*]}" \
           "install them with your package manager, then re-run"
}

# Populate INSTALL_VERSION / INSTALL_PREFIX from flags, falling back to env
# (CLI > env, matching the tool's config precedence). Accepts a leading "v"
# on versions (tags are v-prefixed) but stores the bare x.y.z.
parse-args() {
  INSTALL_VERSION="${VER_BUMP_INSTALL_VERSION:-}"
  INSTALL_PREFIX="${VER_BUMP_PREFIX:-$HOME/.local}"
  while [ $# -gt 0 ]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --version=?*)
        INSTALL_VERSION="${1#--version=}"
        ;;
      --version)
        [ -n "${2:-}" ] || bail 2 "--version requires a value" "e.g. --version 2.0.0"
        INSTALL_VERSION=$2
        shift
        ;;
      --prefix=?*)
        INSTALL_PREFIX="${1#--prefix=}"
        ;;
      --prefix)
        [ -n "${2:-}" ] || bail 2 "--prefix requires a value" "e.g. --prefix \$HOME/.local"
        INSTALL_PREFIX=$2
        shift
        ;;
      --version=|--prefix=)
        bail 2 "${1%=} requires a value"
        ;;
      *)
        usage >&2
        bail 2 "unknown option: $1"
        ;;
    esac
    shift
  done

  INSTALL_VERSION="${INSTALL_VERSION#v}"
  if [ -n "$INSTALL_VERSION" ] && ! is_semver "$INSTALL_VERSION"; then
    bail 2 "not a valid SemVer version: ${INSTALL_VERSION}" \
           "expected x.y.z, e.g. VER_BUMP_INSTALL_VERSION=2.0.0"
  fi
}

install-paths() {
  SHARE_DIR="${INSTALL_PREFIX}/share/ver-bump"
  BIN_DIR="${INSTALL_PREFIX}/bin"
  BIN_LINK="${BIN_DIR}/VerBump"
}

# asset-url <file> — release-asset URL for <file>: GitHub's stable
# latest-release alias when no version is pinned, the tag path when one is.
# Both forms work identically with curl and wget — no API, no JSON, no
# rate limits.
asset-url() {
  if [ -n "$INSTALL_VERSION" ]; then
    printf 'https://github.com/%s/releases/download/v%s/%s\n' \
      "$REPO_SLUG" "$INSTALL_VERSION" "$1"
  else
    printf 'https://github.com/%s/releases/latest/download/%s\n' \
      "$REPO_SLUG" "$1"
  fi
}

# http_fetch <url> <dest> — the single network seam. Tests stub this
# function to serve local fixture files instead.
http_fetch() {
  if have_cmd curl; then
    curl -fsSL --retry 2 -o "$2" "$1"
  else
    wget -q -O "$2" "$1"
  fi
}

sha256_of() {
  local line
  if have_cmd sha256sum; then
    line=$(sha256sum "$1") || return 1
  else
    line=$(shasum -a 256 "$1") || return 1
  fi
  printf '%s\n' "${line%% *}"
}

# verify_checksum <file> <sumfile> — compare <file>'s sha256 against the
# first field of <sumfile> (`sha256sum` output format). A sumfile whose
# first field isn't a 64-char hex digest is rejected outright — that is
# what a mis-served HTML error page looks like.
verify_checksum() {
  local file=$1 sumfile=$2 expected actual rest
  local hex_re='^[0-9a-fA-F]{64}$'
  read -r expected rest < "$sumfile" || true
  if ! [[ "$expected" =~ $hex_re ]]; then
    printf 'VerBump install: checksum file is malformed (expected a sha256 digest)\n' >&2
    return 1
  fi
  actual=$(sha256_of "$file") || return 1
  if [ "$actual" != "$expected" ]; then
    printf 'VerBump install: checksum mismatch for %s\n  expected: %s\n  actual:   %s\n' \
      "${file##*/}" "$expected" "$actual" >&2
    return 1
  fi
}

# unpack-tarball <tarball> <dest-dir> — extract, then sanity-check the
# layout so a wrong or truncated asset can never be swapped into place.
unpack-tarball() {
  tar -xzf "$1" -C "$2" || return 1
  [ -f "$2/ver-bump.sh" ] && [ -d "$2/lib" ]
}

# read-tree-version <dir> — the "version" field of the unpacked
# package.json, parsed with bash alone (jq is a VerBump runtime dep, not
# an installer one). Prints "unknown" rather than failing: version display
# is cosmetic, the checksum is the integrity gate.
read-tree-version() {
  local line re='"version"[[:space:]]*:[[:space:]]*"([^"]+)"'
  if [ -f "$1/package.json" ]; then
    while IFS= read -r line; do
      if [[ "$line" =~ $re ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
      fi
    done < "$1/package.json"
  fi
  printf 'unknown\n'
}

# install-tree <src-dir> — rename swap with rollback. The verified tree is
# staged next to the destination (same filesystem, so the swap is a plain
# rename, never a partial cross-device copy), any previous install is moved
# aside — not deleted — and only removed once the new tree and symlink are
# in place. A failure mid-swap puts the previous install back (R-DIST-5);
# a re-run upgrades in place (R-DIST-3).
install-tree() {
  local src=$1
  mkdir -p "$BIN_DIR" "${SHARE_DIR%/*}" || return 1

  STAGED_DIR="${SHARE_DIR}.staged.$$"
  rm -rf "$STAGED_DIR" || return 1
  mv "$src" "$STAGED_DIR" || return 1
  chmod +x "$STAGED_DIR/ver-bump.sh" || return 1

  # 1. Move any previous install aside, kept for rollback.
  BACKUP_DIR=""
  if [ -e "$SHARE_DIR" ]; then
    BACKUP_DIR="${SHARE_DIR}.bak.$$"
    rm -rf "$BACKUP_DIR" || return 1
    mv "$SHARE_DIR" "$BACKUP_DIR" || return 1
  fi

  # 2.+3. Swap the new tree in and point the symlink at it.
  if ! mv "$STAGED_DIR" "$SHARE_DIR" || \
     ! ln -sfn "$SHARE_DIR/ver-bump.sh" "$BIN_LINK"; then
    _restore-backup
    return 1
  fi
  STAGED_DIR=""

  # 4. Only now is the previous install gone.
  if [ -n "$BACKUP_DIR" ]; then
    rm -rf "$BACKUP_DIR"
    BACKUP_DIR=""
  fi
}

# Undo a failed swap: clear whatever half-state sits at SHARE_DIR and put
# the moved-aside previous install back. Best-effort — this runs on the
# failure path — but a backup that cannot be moved back is preserved and
# named, never deleted.
_restore-backup() {
  rm -rf "$SHARE_DIR"
  if [ -n "$BACKUP_DIR" ] && [ -e "$BACKUP_DIR" ]; then
    if mv "$BACKUP_DIR" "$SHARE_DIR"; then
      BACKUP_DIR=""
      printf 'VerBump install: swap failed — previous installation restored\n' >&2
    else
      printf 'VerBump install: swap failed — previous installation preserved at %s\n' \
        "$BACKUP_DIR" >&2
    fi
  fi
}

# Warn when the bin dir isn't on PATH — the most common "installed but
# command not found" support question.
_path-hint() {
  case ":$PATH:" in
    *":${BIN_DIR}:"*) ;;
    *)
      printf 'Note: %s is not on your PATH. Add it, e.g.:\n' "$BIN_DIR"
      # shellcheck disable=SC2016  # $PATH must stay literal in the shown command
      printf '  export PATH="%s:$PATH"\n' "$BIN_DIR"
      ;;
  esac
}

cleanup() {
  [ -n "${WORK_DIR:-}" ] && rm -rf "$WORK_DIR"
  [ -n "${STAGED_DIR:-}" ] && rm -rf "$STAGED_DIR"
  # BACKUP_DIR is deliberately not removed here: if a failed swap could not
  # restore it, it is the user's previous install — never delete it.
  return 0
}

main() {
  parse-args "$@"
  check-install-deps
  install-paths

  trap cleanup EXIT
  WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ver-bump-install.XXXXXX") || \
    bail 1 "could not create a temporary directory"

  printf 'Installing VerBump (%s) to %s ...\n' \
    "${INSTALL_VERSION:-latest}" "$INSTALL_PREFIX"

  local url
  url=$(asset-url "$ASSET_NAME")
  http_fetch "$url" "$WORK_DIR/$ASSET_NAME" || \
    bail 1 "download failed: $url" \
           "releases before 2.0.0 have no install assets — pin one that does: VER_BUMP_INSTALL_VERSION=x.y.z"
  url=$(asset-url "$ASSET_NAME.sha256")
  http_fetch "$url" "$WORK_DIR/$ASSET_NAME.sha256" || \
    bail 1 "download failed: $url" \
           "the release is missing its .sha256 asset — refusing to install unverified"

  verify_checksum "$WORK_DIR/$ASSET_NAME" "$WORK_DIR/$ASSET_NAME.sha256" || \
    bail 1 "sha256 verification failed — nothing was installed" \
           "re-run to retry; a persistent mismatch means the asset is corrupt or tampered with"

  mkdir -p "$WORK_DIR/tree" || bail 1 "could not prepare the unpack directory"
  unpack-tarball "$WORK_DIR/$ASSET_NAME" "$WORK_DIR/tree" || \
    bail 1 "unexpected tarball layout (no ver-bump.sh + lib/) — nothing was installed"

  local installed_version
  installed_version=$(read-tree-version "$WORK_DIR/tree")
  install-tree "$WORK_DIR/tree" || \
    bail 1 "could not install to ${SHARE_DIR}" \
           "check permissions, or point VER_BUMP_PREFIX at a writable prefix"

  printf 'Installed VerBump %s\n' "$installed_version"
  printf '  %s -> %s\n' "$BIN_LINK" "$SHARE_DIR/ver-bump.sh"
  _path-hint
  printf "Tip: run 'VerBump --install-completions' to set up shell completions.\n"
}

# Run main when executed or piped into bash; skip it when sourced (tests
# source this file to drive the functions above directly). Unlike the
# "$0" = "$BASH_SOURCE" guard in ver-bump.sh, this idiom also fires for
# `curl … | bash`, where BASH_SOURCE is empty.
if ! (return 0 2>/dev/null); then
  main "$@"
fi
