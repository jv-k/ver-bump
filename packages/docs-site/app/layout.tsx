import { RootProvider } from 'fumadocs-ui/provider/next';
import './global.css';
import { Inter } from 'next/font/google';
import type { Metadata } from 'next';

const inter = Inter({
  subsets: ['latin'],
});

export const metadata: Metadata = {
  metadataBase: new URL('https://verbump.jvk.to'),
  title: {
    template: '%s | VerBump',
    default: 'VerBump — plain-bash release tool',
  },
  description:
    'Release tool for any Git repo: reads your Conventional Commits to suggest a SemVer bump, then updates the changelog, tags, and pushes. No Node toolchain — just git + jq.',
};

export default function Layout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="en" className={inter.className} suppressHydrationWarning>
      <body className="flex flex-col min-h-screen">
        <RootProvider>{children}</RootProvider>
      </body>
    </html>
  );
}
