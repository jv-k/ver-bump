# Non-interactive mode

`-y` / `--yes` lets CI (US-4) and scripts run VerBump with no prompts.
Resolved PRD Q-1 in favour of shipping in 2.0.

| ID | Requirement | Status |
| --- | --- | --- |
| R-YES-1 | `-y`/`--yes` auto-accepts the version prompt (suggestion or `-v` value) and the push confirmation. | ✅ shipped — `test/args.bats` |
| R-YES-2 | `--yes` honoured by `--undo`'s confirmation, regardless of flag order in argv. | ✅ shipped — `test/undo.bats` |
| R-YES-3 | `FLAG_YES` is **not** a supported `.verbumprc` key — auto-confirmation is an explicit per-invocation choice, never a repo default. | ✅ by design (`_CONFIG_KEYS` excludes it) |

Modules: `lib/args.sh`, `lib/version.sh` (version prompt),
`lib/git-actions.sh` (push + undo confirmations).
