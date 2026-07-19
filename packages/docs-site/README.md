# docs-site

The VerBump **user docs** site ([verbump.jvk.to](https://verbump.jvk.to)) — a
[Fumadocs](https://fumadocs.dev) (Next.js) app, private to this workspace and
never published to npm. See ADR-22 in [`docs/ADR.md`](../../docs/ADR.md) for
the documentation architecture.

This repo is pnpm-only (see [`docs/CODE_STYLE.md`](../../docs/CODE_STYLE.md)).
From the repo root:

```sh
pnpm docs:dev     # dev server
pnpm docs:build   # production build (what Vercel runs)
```

## Layout

| Path | Description |
| --- | --- |
| `content/docs/` | The MDX pages; sidebar order lives in `meta.json` files. |
| `app/(home)` | Landing page. |
| `app/docs` | Documentation layout and pages. |
| `lib/shared.ts` | Site name and GitHub repo constants. |
| `app/global.css` | Brand color tokens (`--color-vb-*`) and theme accents. |
| `vercel.json` | Skips deploys when neither the site nor the workspace files changed. |

Deployment: Vercel builds this package (root directory `packages/docs-site`)
on every push; production tracks `main`, PRs get preview deploys.
