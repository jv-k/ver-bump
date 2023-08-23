#!/bin/bash

git submodule add --force https://github.com/bats-core/bats-core.git test/bats
git submodule add --force https://github.com/bats-core/bats-support.git test/test_helper/bats-support
git submodule add --force https://github.com/bats-core/bats-assert.git test/test_helper/bats-assert
git submodule add --force https://github.com/jasonkarns/bats-mock.git test/test_helper/bats-mocks
