# CLI options & parsing

GNU-style long options over a Bash-3.2 `getopts` core: long flags are
normalized to their short forms before parsing.

| ID | Requirement | Status |
| --- | --- | --- |
| R-OPT-1 | Every short flag has a GNU long form; `--name value` and `--name=value` both parse. | ✅ shipped — `normalize-long-opts` |
| R-OPT-2 | Boolean long options reject `--name=value` (exit `2`). | ✅ shipped |
| R-OPT-3 | Unknown long options exit `2` naming the option. | ✅ shipped |
| R-OPT-4 | `--` stops option processing; remaining argv forwarded verbatim. | ✅ shipped |
| R-OPT-5 | `--completions <bash\|zsh\|fish>` — see [completions](../completions/requirements.md). | ✅ shipped |
| R-OPT-6 | `-t`/`--tag-prefix` and `-B`/`--branch-prefix` overrides used consistently by every tag/branch step. | ✅ shipped — `test/prefixes.bats`; honoured by `--undo` too (`d32d426`) |
| R-OPT-7 | Repo's own `package-lock.json` bumped built-in; `-f` is for *additional* files. | ✅ shipped |
| R-OPT-8 | `--about` prints branded info, exit 0, no repo needed; bare `-v`/`--version` prints `VerBump <ver>` (parseable when colour is off). | ✅ shipped (`988fa8c`, `27014c7`) — `test/about.bats` |

Pre-scanned modes (`--about`, `--undo`, `--completions`,
`--install-completions`, `--release`, `--major/--minor/--patch`) are handled
in `normalize-long-opts` before `getopts` runs; flags they honour
(`-d`, `-y`, `-t`, `-B`) are pre-scanned from anywhere in argv.

Known doc drift: the `normalize-long-opts` header comment says unknown long
options "exit 1"; the code (correctly, per R-OPT-3) uses `fail 2`.

Modules: `lib/args.sh`, `lib/usage.sh`. Tests: `test/args.bats` (76),
`test/prefixes.bats`.
