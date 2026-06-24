#!/bin/bash

# shellcheck disable=SC2288
true

# If there are no commits in repo, quit, because you can't tag with zero commits.
check-commits-exist() {
  if ! git rev-parse HEAD &> /dev/null; then
    fail 3 \
      "Your current branch doesn't have any commits yet. Can't tag without at least one commit." \
      "Make an initial commit first: git commit --allow-empty -m 'initial commit'."
  fi
}

#
check-branch-notexist() {
  [ "$FLAG_BRANCH" = true ] || return 0
  if git rev-parse --verify "${REL_PREFIX}${V_NEW}" &> /dev/null; then
    fail 3 \
      "Branch <${REL_PREFIX}${V_NEW}> already exists." \
      "Delete the existing branch (git branch -D ${REL_PREFIX}${V_NEW}), pick a different version, or drop --branch/--pr to tag in place instead."
  fi
}

# Only tag if tag doesn't already exist
check-tag-exists() {
  local TAG_MSG
  TAG_MSG=$( git tag -l "${TAG_PREFIX}${V_NEW}" )
  if [ -n "$TAG_MSG" ]; then
    fail 3 \
      "A release with that tag version number already exists: ${TAG_MSG}" \
      "Delete the existing tag with: git tag -d ${TAG_MSG}, or pick a different version."
  fi
}
