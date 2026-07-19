'use client';

import { useState } from 'react';
import { Check, Copy } from 'lucide-react';

const COMMAND =
  'curl -fsSL https://raw.githubusercontent.com/jv-k/VerBump/main/install.sh | bash';

export function InstallCommand() {
  const [copied, setCopied] = useState(false);

  async function copy() {
    await navigator.clipboard.writeText(COMMAND);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  return (
    <div className="flex items-center gap-3 rounded-lg border bg-fd-secondary pl-6 pr-3 py-3 mb-12 max-w-full">
      <pre className="text-left text-sm overflow-x-auto">
        <code>{COMMAND}</code>
      </pre>
      <button
        type="button"
        onClick={copy}
        aria-label="Copy install command"
        className="shrink-0 rounded-md border p-2 hover:bg-fd-accent transition-colors"
      >
        {copied ? (
          <Check className="size-4 text-vb-green" aria-hidden />
        ) : (
          <Copy className="size-4 text-fd-muted-foreground" aria-hidden />
        )}
      </button>
    </div>
  );
}
