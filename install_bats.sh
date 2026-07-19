#!/bin/bash
# Installs the bats test harness as plain, git-ignored clones (not submodules).
# Clones are pinned to release tags — unpinned HEAD once pulled in an
# unreleased bats-core formatter change that broke pretty output.
set -e

clone() {
  local url="$1" tag="$2" dest="$3"
  rm -rf "$dest"
  git clone --depth 1 --branch "$tag" "$url" "$dest"
}

clone https://github.com/bats-core/bats-core.git v1.13.0 test/bats
clone https://github.com/bats-core/bats-support.git v0.3.0 test/test_helper/bats-support
clone https://github.com/bats-core/bats-assert.git v2.2.4 test/test_helper/bats-assert
clone https://github.com/jasonkarns/bats-mock.git v1.2.5 test/test_helper/bats-mocks
