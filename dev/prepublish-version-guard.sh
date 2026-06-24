#!/usr/bin/env bash
# dev/prepublish-version-guard.sh — wired as npm "prepublishOnly".
#
# Fails the publish if package.json version does not match the current git tag.
# Guarantees the published CLI's `--version` (which reads package.json) matches
# the tag users installed, so the registry artifact can never self-report a
# different version than the tag it was cut from.
set -euo pipefail

pkg_version=$(node -p "require('./package.json').version")
git_tag=$(git describe --tags --exact-match 2>/dev/null || true)

if [ -z "$git_tag" ]; then
  echo "prepublish: HEAD is not an exact tag; refusing to publish. Publish from a vX.Y.Z tag." >&2
  exit 1
fi

if [ "v${pkg_version}" != "$git_tag" ]; then
  echo "prepublish: version mismatch — package.json=${pkg_version} but tag=${git_tag}" >&2
  exit 1
fi

echo "prepublish: version OK (${git_tag})"
