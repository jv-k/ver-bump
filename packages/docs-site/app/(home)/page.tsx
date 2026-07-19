import Link from 'next/link';

const features = [
  {
    title: 'Suggests the right bump',
    body: 'Reads your Conventional Commits to propose the next SemVer, prereleases included.',
  },
  {
    title: 'Writes the changelog',
    body: 'Flat or grouped by commit type, with commit, PR, and compare links.',
  },
  {
    title: 'Bumps any file',
    body: 'package.json, pyproject.toml, Chart.yaml, a Go const, any {{version}} text pattern.',
  },
  {
    title: 'Three workflows',
    body: 'Tag in place, cut a release branch, or open a GitHub PR.',
  },
  {
    title: 'Safe by default',
    body: 'Preflight checks, --dry-run previews every side-effect, --undo rolls back.',
  },
  {
    title: 'Nothing to install but bash',
    body: 'git and jq are the only runtime dependencies.',
  },
];

export default function HomePage() {
  return (
    <main className="flex flex-col items-center flex-1 px-4 py-16 text-center">
      <h1 className="text-4xl font-bold tracking-tight mb-4">VerBump</h1>
      <p className="text-lg text-fd-muted-foreground max-w-xl mb-8">
        A plain-bash release tool for any Git repo. Conventional Commits in,
        SemVer bump, changelog, tag, and push out — no Node toolchain, just{' '}
        <code>git</code> + <code>jq</code>.
      </p>
      <div className="flex gap-3 mb-12">
        <Link
          href="/docs/quickstart"
          className="rounded-lg bg-fd-primary px-5 py-2.5 font-medium text-fd-primary-foreground"
        >
          Quickstart
        </Link>
        <Link href="/docs" className="rounded-lg border px-5 py-2.5 font-medium">
          Documentation
        </Link>
      </div>
      <pre className="rounded-lg border bg-fd-secondary px-6 py-4 text-left text-sm mb-12 overflow-x-auto max-w-full">
        <code>
          curl -fsSL https://raw.githubusercontent.com/jv-k/VerBump/main/install.sh
          | bash
        </code>
      </pre>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 max-w-4xl text-left">
        {features.map((f) => (
          <div key={f.title} className="rounded-lg border p-4">
            <h2 className="font-semibold mb-1">{f.title}</h2>
            <p className="text-sm text-fd-muted-foreground">{f.body}</p>
          </div>
        ))}
      </div>
    </main>
  );
}
