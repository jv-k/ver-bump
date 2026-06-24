#!/usr/bin/env bash
#
# dev/sandbox.sh — run ver-bump.sh against a throwaway git repo.
#
# Creates a temp dir with an initialised git repo, a minimal package.json,
# and a couple of seed commits, then invokes ver-bump from inside it. The
# sandbox is wiped on exit unless --keep is passed.
#
# All unrecognised flags are forwarded to ver-bump. Environment overrides:
#   SANDBOX_VERSION  starting "version" in package.json (default: 0.1.0)
#   SANDBOX_COMMITS  semicolon-separated extra commit subjects to seed, e.g.:
#                      SANDBOX_COMMITS='feat: thing; fix: other' ./dev/sandbox.sh
#
# Usage:
#   ./dev/sandbox.sh                         # interactive, with auto-suggested bump
#   ./dev/sandbox.sh -v 2.0.0                # non-interactive, explicit version
#   ./dev/sandbox.sh --dry-run --no-branch   # try long options
#   ./dev/sandbox.sh --keep                  # don't wipe the sandbox on exit
#
# After a run with --keep you can `cd` into the printed path to poke around.

set -eo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VER_BUMP="${REPO_ROOT}/ver-bump.sh"

if [ ! -x "$VER_BUMP" ]; then
  echo "sandbox: ver-bump.sh not found or not executable at $VER_BUMP" >&2
  exit 1
fi

KEEP=0
QUIET=0
PASSTHROUGH=()
while (( $# )); do
  case "$1" in
    -k|--keep) KEEP=1; shift ;;
    -q|--quiet) QUIET=1; shift ;;
    -h|--help-sandbox)
      # Pass -h / --help through to ver-bump; print our own help only for
      # this long alias so we don't shadow ver-bump's usage output.
      sed -n '3,20p' "${BASH_SOURCE[0]}"
      exit 0
    ;;
    *) PASSTHROUGH+=("$1"); shift ;;
  esac
done

# When --quiet, swallow the sandbox's own status chatter so recordings only
# show ver-bump output. Errors still go through because set -eo pipefail will
# abort the script and the trap prints the --keep path if applicable.
say() {
  (( QUIET )) && return 0
  printf '%s\n' "$*" >&2
}

SANDBOX_VERSION="${SANDBOX_VERSION:-0.1.0}"
SANDBOX_DIR="$(mktemp -d -t ver-bump-sandbox.XXXXXX)"

cleanup() {
  local rc=$?
  if (( KEEP )); then
    echo
    echo "sandbox: preserved at $SANDBOX_DIR (--keep)" >&2
  else
    rm -rf "$SANDBOX_DIR"
  fi
  exit "$rc"
}
trap cleanup EXIT INT TERM

say "sandbox: $SANDBOX_DIR"
cd "$SANDBOX_DIR"

# Minimal package.json — the single mandatory input ver-bump cares about
cat > package.json <<EOF
{
  "name": "sandbox-app",
  "version": "${SANDBOX_VERSION}",
  "description": "Throwaway sandbox for exercising ver-bump."
}
EOF

# Isolated git repo. Force a deterministic identity and default branch so
# this works in CI and on fresh machines without a global git config.
git init --quiet --initial-branch=main 2>/dev/null || git init --quiet
git config user.email "sandbox@ver-bump.local"
git config user.name  "ver-bump sandbox"
git config commit.gpgsign false

git add package.json
git commit --quiet -m "chore: initial commit"

# Tag the initial commit with the starting version so the conventional-commit
# bump suggestion has a "since <prev>" range to look at. Honours -t/--tag-prefix
# if the caller passed one through; otherwise uses ver-bump's default "v".
sandbox_tag_prefix="v"
for ((i=0; i<${#PASSTHROUGH[@]}; i++)); do
  case "${PASSTHROUGH[i]}" in
    -t|--tag-prefix) sandbox_tag_prefix="${PASSTHROUGH[i+1]}" ;;
    --tag-prefix=*)  sandbox_tag_prefix="${PASSTHROUGH[i]#--tag-prefix=}" ;;
  esac
done
git tag -a "${sandbox_tag_prefix}${SANDBOX_VERSION}" -m "Seed tag" 2>/dev/null || true

# Seed extra commits so the conventional-commit bump suggestion has
# something to chew on. Default seeds exercise major+minor+patch paths.
declare -a seeds
if [ -n "${SANDBOX_COMMITS:-}" ]; then
  IFS=';' read -r -a seeds <<< "$SANDBOX_COMMITS"
else
  seeds=(
    "feat: add shiny new thing"
    "fix: patch the leaky pipe"
    "docs: tidy README"
  )
fi

for msg in "${seeds[@]}"; do
  # trim surrounding whitespace
  msg="${msg#"${msg%%[![:space:]]*}"}"
  msg="${msg%"${msg##*[![:space:]]}"}"
  [ -z "$msg" ] && continue
  git commit --quiet --allow-empty -m "$msg"
done

say "sandbox: seeded $(git rev-list --count HEAD) commits on $(git rev-parse --abbrev-ref HEAD)"
say "sandbox: running ver-bump ${PASSTHROUGH[*]:-<no args>}"
say "---"

# In --quiet mode, wipe the terminal just before handing off so recordings
# (vhs etc.) see only ver-bump's output — the shell-echoed invocation and
# any seed noise scrolls out of frame.
(( QUIET )) && printf '\033[2J\033[H'

# Run ver-bump. Any exit code from it propagates (set -e) — cleanup trap fires either way.
"$VER_BUMP" ${PASSTHROUGH[@]+"${PASSTHROUGH[@]}"}
