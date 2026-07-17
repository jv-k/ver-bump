# Package-registry publishing

ver-bump does not publish packages to registries (npm, pnpm, yarn, or any
other), and will not grow a `--publish` flag. The release run ends at the git
surface: bump, commit, tag, push, and — with `--release` — a GitHub release.

## Why this is out of scope

Publishing is downstream of the release, and both halves of it are already
well served without ver-bump in the loop:

- **Locally**, `npm publish` is a single command. `ver-bump -p && npm publish`
  gives the correct ordering (publish only after the push succeeded) and a
  distinct failure signal for free — the two guarantees a built-in flag would
  have provided.
- **In CI**, the modern pattern is tokenless OIDC trusted publishing triggered
  by the release event — which is exactly how this repo publishes itself (see
  the `publish-npm` job in `.github/workflows/ci.yml`). ver-bump's `--release`
  flag is the bridge: it creates the GitHub release, CI does the publishing.
  npm is actively steering the ecosystem this way; building interactive local
  publishing into the tool would bake in the legacy workflow.

Building the flag would also take on permanent liabilities that outweigh the
convenience of wrapping one command:

- OTP/2FA prompting inside a bash script that streams `npm` output
- package-manager detection and parity pressure (npm today, pnpm/yarn/deno
  requests tomorrow — multiplied again if monorepo support ever lands)
- a new documented exit code and recovery story ("tag pushed but publish
  failed") that becomes API surface forever

All of that runs against ver-bump's identity: a bash tool with git and jq as
its only runtime dependencies, whose job is the version bump and the git
ceremony around it.

The one genuine footgun a flag would have fixed — a prerelease like
`2.1.0-rc.1` landing on the `latest` dist-tag — is a documentation concern:

```jsonc
// package.json — pin prereleases off `latest` without any tooling:
{ "publishConfig": { "tag": "next" } }
```

## Prior requests

- #95 — "Publish to npm as part of the release run"
