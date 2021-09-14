```
 _ _  ___  ___       ___  _ _  __ __  ___  
| | || __>| . \ ___ | . >| | ||  \  \| . \
| ' || _> |   /|___|| . \| ' ||     ||  _/
|__/ |___>|_\_\     |___/\___/|_|_|_||_|  

```

[![Node.js Package](https://github.com/jv-k/ver-bump/actions/workflows/npm-publish.yml/badge.svg)](https://github.com/jv-k/ver-bump/actions/workflows/npm-publish.yml) [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)

## Description:
This script automates bumping the git software project's version using automation. It's written in 100% pure bash and npm, the NodeJS task runner.
     
It does several things that are typically required for releasing a Git repository, like git tagging, automatic updating of CHANGELOG.md, and incrementing the version number in various JSON files. It:

- Increments / suggests the current software project's version number
- Adds a Git tag, named after the chosen version number
- Updates CHANGELOG.md
- Updates VERSION file
- Creates a release branch (disable with `-v`) + switches to it (following the [Git branch-based workflow](https://nvie.com/posts/a-successful-git-branching-model/))
- Commits files to release branch
- Pushes to a remote (optionally)
- Updates `"version" : "x.x.x"` tag in JSON files if [-v file1 -v file2...] argument is supplied.

## Installation
Simply clone the repo and copy `ver-bump.sh` to your project's root.

You may need to set execute permissions for the script, eg `$ chmod 755 ver-bump.sh`

## Usage
```
$ ./ver-bump.sh [-v <version no>] [-m <release message>] [-j <file1>] [-j <file2>].. [-n] [-p] [-b] [-h]

Options:

-v <version number>     Specify a manual version number
-m <release message>    Custom release message
-f <filename.json>      Update version number inside JSON files.
                            * For multiple files, add a separate -f option for each one,
                            * For example: ./ver-bump.sh -f src/plugin/package.json -f composer.json
-p <repository alias>   Push commits to remote repository, eg `-p Origin`
-n                      Turns off automatic commit
                            * You may want to do that yourself, for example.
-b                      Don't create automatic `release-<version>` branch
-h 	                    Show help message.
```

## Credits
https://github.com/jv-k/ver-bump.sh

Inspired by the scripts from [@pete-otaqu](https://gist.github.com/pete-otaqui/4188238) and [@mareksuscak](https://gist.github.com/mareksuscak/1f206fbc3bb9d97dec9c).

# License
Released under the [MIT license.](https://github.com/jv-k/ver-bump.sh/blob/master/LICENSE) 
