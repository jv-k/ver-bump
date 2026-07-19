'use client';

import { Terminal } from 'lucide-react';
import { DynamicCodeBlock } from 'fumadocs-ui/components/dynamic-codeblock';

const COMMAND =
  'curl -fsSL https://raw.githubusercontent.com/jv-k/VerBump/main/install.sh | bash';

export function InstallCommand() {
  return (
    <div className="rounded-lg border bg-fd-secondary mb-12 w-full max-w-3xl text-left">
      <div className="flex items-center gap-2 border-b px-4 py-2 text-xs text-fd-muted-foreground">
        <Terminal className="size-3.5" aria-hidden />
        Install VerBump:
      </div>
      <div className="p-2">
        <DynamicCodeBlock lang="bash" code={COMMAND} />
      </div>
    </div>
  );
}
