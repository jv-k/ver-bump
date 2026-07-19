#!/bin/bash
# Installs the bats test harness as plain, git-ignored clones (not submodules).
set -e

clone() {
  local url="$1" dest="$2"
  rm -rf "$dest"
  git clone --depth 1 "$url" "$dest"
}

clone https://github.com/bats-core/bats-core.git test/bats
clone https://github.com/bats-core/bats-support.git test/test_helper/bats-support
clone https://github.com/bats-core/bats-assert.git test/test_helper/bats-assert
clone https://github.com/jasonkarns/bats-mock.git test/test_helper/bats-mocks
