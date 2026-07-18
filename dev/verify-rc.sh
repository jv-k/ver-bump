#!/usr/bin/env bash
#
# verify-rc.sh — post-cut verification for a VerBump release candidate.
#   Usage:  ./verify-rc.sh 2.0.0-rc.1
#
# Read-only against the published rc; only creates throwaway temp dirs.
# Checks:
#   1. GitHub release exists, is a prerelease, has generated notes  (--release + gh --generate-notes, ADR-18)
#   2. npm dist-tag `next` points at the rc + provenance metadata   (OIDC trusted publishing)
#   3. Clean npm install runs with node STRIPPED from PATH          (default path = bash/git/jq only, ADR-15)
#   4. An unknown .verbumprc key emits the warning                 (ADR-05 / R-CFG-7)
# Exits non-zero if any check fails. Requires: gh (authed), npm, git, jq.
set -uo pipefail

VER="${1:?usage: verify-rc.sh <version>   e.g. 2.0.0-rc.1}"
TAG="v${VER}"
REPO="jv-k/VerBump"
BIN=""                       # set by check 3, reused by check 4
pass=0; fail=0
ok(){ printf '   \033[32m✓\033[0m %s\n' "$1"; pass=$((pass + 1)); }
no(){ printf '   \033[31m✗\033[0m %s\n' "$1"; fail=$((fail + 1)); }

echo "▶ 1/4  GitHub release ${TAG} — prerelease with generated notes"
if info=$(gh release view "$TAG" --repo "$REPO" --json isPrerelease,body 2>/dev/null); then
  if [ "$(printf '%s' "$info" | jq -r .isPrerelease)" = "true" ]; then ok "marked as prerelease"; else no "NOT marked prerelease"; fi
  blen=$(printf '%s' "$info" | jq -r '.body | length')
  if [ "${blen:-0}" -gt 0 ]; then ok "notes non-empty (${blen} chars) — --release/gh --generate-notes worked"; else no "release notes EMPTY"; fi
else
  no "release ${TAG} not found (did the --release step run?)"
fi

echo "▶ 2/4  npm dist-tag 'next' + provenance"
nt=$(npm view VerBump dist-tags.next 2>/dev/null || true)
if [ "$nt" = "$VER" ]; then ok "dist-tag next → ${VER}"; else no "dist-tag next is '${nt:-<none>}' (expected ${VER}; CI publish may still be running)"; fi
if npm view "VerBump@${VER}" --json 2>/dev/null | grep -qiE 'provenance|attestation|sigstore'; then
  ok "provenance/attestation metadata present"
else
  no "no provenance metadata found (OIDC publish not done yet?)"
fi

echo "▶ 3/4  clean install runs with node STRIPPED from PATH (default-path purity)"
tmp=$(mktemp -d); mkdir -p "$tmp/pfx"
if npm install -g --prefix "$tmp/pfx" "VerBump@${VER}" >/dev/null 2>&1; then
  BIN="$tmp/pfx/bin/VerBump"
  if [ -x "$BIN" ]; then ok "installed VerBump ${VER} from npm"; else no "VerBump binary missing after install"; fi
  # keep git/jq (homebrew, /usr/bin), drop any node/npm/nvm/fnm dirs
  nonode=$(printf '%s' "$PATH" | tr ':' '\n' | grep -viE 'node|npm|nvm|fnm|\.n/' | paste -sd: -)
  if v=$(PATH="${nonode}:$tmp/pfx/bin" "$BIN" --version 2>/dev/null); then
    ok "runs with node stripped from PATH: ${v}"
  else
    no "failed to run --version without node on PATH"
  fi
else
  no "npm install VerBump@${VER} failed (not yet on npm?)"
fi

echo "▶ 4/4  behaviour: unknown .verbumprc key warns (ADR-05 / R-CFG-7)"
if [ -n "$BIN" ] && [ -x "$BIN" ]; then
  sb=$(mktemp -d)
  ( cd "$sb" && git init -q \
      && printf '{ "version": "1.0.0" }\n' > package.json \
      && git add -A && git commit -qm seed \
      && printf 'TAG_PREFX=oops\n' > .verbumprc )
  # -n skips commit/tag/push (avoids the interactive push-offer prompt, which -y
  # does not auto-answer); </dev/null hard-guards against any read blocking. The
  # unknown-key warning fires at load-config, before any of that.
  out=$(cd "$sb" && "$BIN" --dry-run -v 1.0.1 --allow-dirty -y -n </dev/null 2>&1 || true)
  if printf '%s\n' "$out" | grep -q "Unknown .verbumprc key 'TAG_PREFX'"; then
    ok "unknown-key warning fired"
  else
    no "unknown-key warning NOT seen"
  fi
  rm -rf "$sb"
else
  no "skipped — no installed binary to exercise"
fi
[ -n "${tmp:-}" ] && rm -rf "$tmp"

# Also worth a manual smoke of the PRIMARY install path (curl), which pulls the
# release tarball + .sha256 uploaded by the publish-release-assets CI job:
#   curl -fsSL "https://raw.githubusercontent.com/${REPO}/${TAG}/install.sh" | VERBUMP_INSTALL_VERSION="${VER}" bash

echo
echo "════ ${pass} passed, ${fail} failed ════"
[ "$fail" -eq 0 ]
