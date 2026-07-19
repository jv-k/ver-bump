import Link from 'next/link';
import Image from 'next/image';
import { InstallCommand } from '@/components/install-command';
import {
  Sparkles,
  ScrollText,
  FileJson,
  GitBranch,
  ShieldCheck,
  Terminal,
} from 'lucide-react';

const features = [
  {
    title: 'Suggests the right bump',
    body: 'Reads your Conventional Commits to propose the next SemVer, prereleases included.',
    icon: Sparkles,
    color: 'var(--color-vb-red)',
  },
  {
    title: 'Writes the changelog',
    body: 'Flat or grouped by commit type, with commit, PR, and compare links.',
    icon: ScrollText,
    color: 'var(--color-vb-orange)',
  },
  {
    title: 'Bumps any file',
    body: 'package.json, pyproject.toml, Chart.yaml, a Go const, any {{version}} text pattern.',
    icon: FileJson,
    color: 'var(--color-vb-yellow)',
  },
  {
    title: 'Three workflows',
    body: 'Tag in place, cut a release branch, or open a GitHub PR.',
    icon: GitBranch,
    color: 'var(--color-vb-green)',
  },
  {
    title: 'Safe by default',
    body: 'Preflight checks, --dry-run previews every side-effect, --undo rolls back.',
    icon: ShieldCheck,
    color: 'var(--color-vb-blue)',
  },
  {
    title: 'Nothing to install but bash',
    body: 'git and jq are the only runtime dependencies.',
    icon: Terminal,
    color: 'var(--color-vb-violet)',
  },
];

export default function HomePage() {
  return (
    <main className="flex flex-col items-center flex-1 px-4 py-16 text-center">
      {/* <h1 className="text-4xl font-bold tracking-tight mb-4">VerBump</h1> */}
      <Image
        src="/social-preview.png"
        alt="VerBump: reads Conventional Commits, suggests the SemVer bump, writes the changelog, tags, and pushes."
        width={1280}
        height={640}
        className="w-full max-w-3xl h-auto rounded-xl border mb-12"
      />
      {/* <p className="text-lg text-fd-muted-foreground max-w-xl mb-8">
        A plain-bash release tool for any Git repo. Conventional Commits in,
        SemVer bump, changelog, tag, and push out — no Node toolchain, just{' '}
        <code>git</code> + <code>jq</code>.
      </p> */}
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
      <InstallCommand />
      {/* <div aria-hidden className="vb-rainbow-bar w-full max-w-4xl mb-10" /> */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 max-w-4xl text-left">
        {features.map((f) => (
          <div key={f.title} className="rounded-lg border p-4">
            <div
              className="vb-icon mb-3 flex size-9 items-center justify-center rounded-lg"
              style={{ '--vb-c': f.color } as React.CSSProperties}
            >
              <f.icon className="size-5" aria-hidden />
            </div>
            <h2 className="font-semibold mb-1">{f.title}</h2>
            <p className="text-sm text-fd-muted-foreground">{f.body}</p>
          </div>
        ))}
      </div>
    </main>
  );
}
