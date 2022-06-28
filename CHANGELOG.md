## 1.1.1 (June 28, 2022)
- chore: updated package.json, updated package-lock.json, updated CHANGELOG.md, bumped 1.1.0 -> 1.1.1
- bugfix: un-capitalised first letter of changelog entry for ver-bump's own commit msg - because the rest of commit messages are lowercase (personal preference... see next bullet) - probably best left to the user to capitalise or not, perhaps don't enforce it (added future option to TODO.md) - updated BATS test case for changelog output assert test
- docs: moved todos into TODO.md
- docs: add demo GIF
- merge: branch 'stable' into main
- merge: branch 'release-1.1.0' into stable

## 1.1.0 (June 26, 2022)
- chore: Updated package.json, updated package-lock.json, updated CHANGELOG.md, bumped 1.0.5 -> 1.1.0
- tests: fixed "would clobber existing tag" error when running action
- docs: document remaining CLI switches
- docs: updated badges for new gh actions
- tests: added test for new -l CLI argument
- tests: update tests after refactors / chores that changed prompts
- feat: added previously implemented options to the CLI help prompt
- chore: changed help + prompt messages for clarity
- chore:  small refactor + capitalise first letter of changlog entry for files that ver-bump changes - following from d4770e5
- feat: fixes #15 added -l argument to the CLI for optional pausing right after changelog is created, - the default previously was to pause and wait for the user to check the changelog and press enter to continue - the default now is to bypass the prompt and make it optional by supplying the -l argument
- feat: added option to add a commit message prefix - By default "chore:  " is used
- refactor: change changelog & commit msg for changes the script makes -> lowercase
- tests: add fetch remote tags - fixes bats test failing when git history needs to be retrieved
- tests: changed versionfile bump tool from sed -> jq
- tests: Fixed changelog.md test
- chore: cleaned up unnecessary comments
- tests: fixed check-tag-exists assert
- tests: added test: check tag doesn't exist
- tests: changed functions to pass shellcheck - the `` Command Substitution that was changed to $() notation is difficult to make work, because of needed multiple double quotes, hence made them pass using exceptions
- chore: moved functions around for correct order
- merge: branch 'chore-unit-tests' into main - merge to add all the new testing functions to github actions
- tests: created test runner action
- chore: renamed test runner npm task for clarity
- chore: rename bats installer script
- merge: branch 'main' into chore-unit-tests - grab latest changes from main development branch
- merge: branch 'tests-shellcheck' into main
- chore: added shellcheck + changed bash scripts as per recommended
- chore: Rename release action for clarity
- tests: add tests for branch functions
- tests: dev commit for push/branch/commit functions
- Merge branch 'main' into chore-unit-tests
- refactor: in bump json files fn, changed to V_PREV -> V_NEW like rest of code + added detection for when version number will remain the same
- refactor: corrected do-changelog message about existing file
- refactor: corrected function name
- docs: moved TODO.md inside README.md + deleted file
- tests: clean up test set-up + added tests - added test for do-packagefile-bump - added test for bump-json-files success + failure + if no version is found (3 tests) - added test for check-tag-exists - added test for do-changelog
- tests: add bats-mock submodule
- tests: Update npm test run cmds + update Bats module
- Merge branch 'main' into chore-unit-tests
- Merge branch 'refactor-tests' into main
- tests: Added install script for BATS test runner
- tests: First commit of batch of unit tests
- refactor: abstractified version suggestion algorithm + changed the new desired version number var name + cleanup
- refactor(for tests): changed exit codes for proper error handling in tests
- refactor(for tests): disable msg styles when sourced + move main functions into main loop - separated styles and icons in prep for test regime, as the styles within the echo statements made them untestable - grabbing output with formatting failed when compared to plain text, or text with the same escape characters. - now the styles don't load when ver-bumped is sourced for testing with BATS
- bugfix: fixed -c disable changelog switch not taking arguments
- Merge branch 'bug-default-version' into main
- fix: failing on when version number unchanged and previously not bumped (#14)
- refactor: change tagging fn for cleaner code in stable module
- merge: branch 'release-1.0.5' into stable
- merge: branch 'release-1.0.5' into main
- Merge branch 'release-1.0.4' into stable
- Merge pull request #13 from jv-k/main
- Merge branch 'release-1.0.3' into stable
- Merge branch 'stable' of github.com:jv-k/ver-bump into stable
- Update docs - fixed broken contrib & license urls

## 1.0.5 (February 04, 2022)
- Updated package.json, Updated package-lock.json, Updated CHANGELOG.md, Bumped 1.0.4 –> 1.0.5
- fix: Removed cross-env dependency. Unreliable detection of package.json parameters. No dependencies now!
- Merge branch 'release-1.0.4' into develop

## 1.0.4 (February 03, 2022)
- Updated package.json, Updated package-lock.json, Updated CHANGELOG.md, Bumped 1.0.3 –> 1.0.4
- Merge branch 'release-1.0.3' into develop
- Updated docs - lil typo
- Merge branch 'release-1.0.2' into develop

## 1.0.3 (January 27, 2022)
- Updated package.json, Updated package-lock.json, Updated CHANGELOG.md, Bumped 1.0.2 –> 1.0.3
- docs: Updated README to remove duplicate table that shows detailed run steps
- Merge branch 'release-1.0.2' into main Fixed #12

## 1.0.2 (October 07, 2021)
- Updated package.json, Updated package-lock.json, Updated CHANGELOG.md, Bumped 1.0.2-beta.1 –> 1.0.2
- Fixes #12
- Update README.md
- Merge pull request #10 from jv-k/release-1.0.2-beta.1
- Updated package.json, Updated CHANGELOG.md, Bumped 1.0.1 –> 1.0.2-beta.1
- Updated package.json, Updated CHANGELOG.md, Bumped 1.0.1 –> 1.0.2-beta.1

## 1.0.2-beta.1 (September 28, 2021)
- Updated package.json, Updated CHANGELOG.md, Bumped 1.0.1 –> 1.0.2-beta.1
- Merge branch 'main' into develop
- Update TODO.md
- Changed webhook for action
- Added build tast
- Publish to GitHub Package Registry and NPM
- Merge branch 'develop' into main
- Merge branch 'release-1.0.1' into develop
- Merge branch 'release-1.0.0' into main - First confident release! 🚀✨
- Merge branch 'release-0.2.4' into main
- Merge branch 'release-0.2.3' into main

## 1.0.1 (September 28, 2021)
- Updated package.json, Updated CHANGELOG.md, Bumped 1.0.0 –> 1.0.1
- Updated docs
- Update README.md
- Merge branch 'release-1.0.0' into develop First confident release! 🚀✨

## 1.0.0 (September 27, 2021)
- Updated package.json, Updated CHANGELOG.md, Bumped 0.2.4 –> 1.0.0
- Bugfix: commit history since last tag wasn't working correctly - missing `v` in tag name
- Updated code comment
- Merge branch 'release-0.2.4' into develop

## 0.2.4 (September 27, 2021)
- Updated package.json, Updated CHANGELOG.md, Bumped 0.2.3 –> 0.2.4
- Cleaned up code comment
- Bugfix: works now with no previous tags
- Added option to disable committing - For debug purposes. Not yet decided to put it in docs, it's not really useful for general usage.
- Update ver-bump CLI credits logo - Stole it from oh-my-zsh..!
- Updated docs From todos:   - [x] Docs: Inform user how the script works in the current branch   - [x] Docs: Local `npm` install   - [x] Docs: Semver + Gh branching model
- Removed placeholder CoC - not required for now!
- Merge branch 'release-0.2.3' into develop

## 0.2.3 (September 22, 2021)
- Updated package.json, Updated CHANGELOG.md, Bumped 0.2.2 –> 0.2.3
- 📕 Add temporary instructions
- 📕 Add npm version badge
- Add issue and Feature request templates
- Merge pull request #6 from jv-k/add-code-of-conduct-1
- Create CODE_OF_CONDUCT.md
- Merge pull request #5 from jv-k/release-0.2.2
- Merge pull request #4 from jv-k/npm-publish-action

## 0.2.2 (September 15, 2021)
- Updated package.json, Updated CHANGELOG.md, Bumped 0.2.1 –> 0.2.2
- Merge branch 'npm-publish-action' into develop
- Added badges to docs
- Update npm-publish.yml
- Update npm-publish.yml
- Merge pull request #3 from jv-k/release-0.2.1
- Merge branch 'release-0.2.1' into develop
- Update README.md
- Merge pull request #2 from jv-k/jv-k-patch-1
- Add NPM publish badge
- Create npm-publish.yml
- Merge pull request #1 from jv-k/release-0.2.0
- Merge branch 'release-0.1.4' into main
- Merge branch 'release-0.1.3' into master
- Merge branch 'release-0.1.3'
- Merge branch 'release-0.1.2'
- Merge branch 'release-0.1.0'

## 0.2.1 (September 14, 2021)
- Updated package.json, Updated CHANGELOG.md, Bumped 0.2.0 –> 0.2.1
- 🧹 comments
- Merge branch 'release-0.2.0' into develop

## 0.2.0 (August 25, 2021)
- Updated package.json, Updated CHANGELOG.md, Bumped 0.1.4 –> 0.2.0
- Move helper functions to separate file
- Read version from package.json Remove default fetch of version from VERSION file Updated comments
- Saving commit
- Merge branch 'release-0.1.4' into develop
- Updated VERSION, Updated CHANGELOG.md, Bumped 0.1.3 –> 0.1.4
- Updated VERSION, Updated CHANGELOG.md, Bumped 0.1.3 –> 0.1.4

## 0.1.4 (August 17, 2021)
- Updated VERSION, Updated CHANGELOG.md, Bumped 0.1.3 –> 0.1.4
- Renamed script + update docs
- Move bash colours/styles to separate file
- Allow help to show without a commit present
- Merge branch 'release-0.1.3' into develop
- Fix: Git message was repeating
- Merge branch 'release-0.1.3' into develop

## 0.1.3 (November 27, 2020)
- Updated VERSION, Updated CHANGELOG.md, Bumped 0.1.2 –> 0.1.3
- Fixed: Docs: Added -b to usage
- Merge branch 'release-0.1.2' into develop

## 0.1.2 (November 27, 2020)
- Updated VERSION, Updated CHANGELOG.md, Bumped 0.1.1 –> 0.1.2
- Fix: line break issue in help msg
- Removed hard-coded version no. in script
- Fixed CHANGELOG commit message bug
- Merge branch 'release-0.1.1' into develop

## 0.1.1 (November 27, 2020)
- Updated VERSION, Updated CHANGELOG.md, Bumped 0.1.0 –> 0.1.1
- Docs: Added entry for -b argument (disables branch creation)
- Merge branch 'release-0.1.0' into develop
- Added gitignore

## 0.1.0 (November 27, 2020)
- Created VERSION, Created CHANGELOG.md, Bumped to 0.1.0
- 🚀 Initial commit

