# ver-bump — project instructions

## Package manager

Use **pnpm**, not npm. When suggesting or running scripts from `package.json`,
always prefer `pnpm run <script>` / `pnpm <cmd>`. The repo's lockfile is
`pnpm-lock.yaml`; treat `package-lock.json` as stale if it appears.
