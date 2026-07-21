import defaultMdxComponents from 'fumadocs-ui/mdx';
import type { MDXComponents } from 'mdx/types';
import { Check, Minus, X } from 'lucide-react';

// Inline verdict glyphs for feature/comparison tables (lucide icons instead
// of emoji, so they follow the site's type scale and theme).
function Yes() {
  return (
    <Check
      className="inline h-4 w-4 align-text-bottom text-green-600 dark:text-green-500"
      aria-label="Yes"
    />
  );
}

function No() {
  return (
    <X
      className="inline h-4 w-4 align-text-bottom text-zinc-400 dark:text-zinc-500"
      aria-label="No"
    />
  );
}

function Partial() {
  return (
    <Minus
      className="inline h-4 w-4 align-text-bottom text-amber-500"
      aria-label="Partial"
    />
  );
}

export function getMDXComponents(components?: MDXComponents) {
  return {
    ...defaultMdxComponents,
    Yes,
    No,
    Partial,
    ...components,
  } satisfies MDXComponents;
}

export const useMDXComponents = getMDXComponents;

declare global {
  type MDXProvidedComponents = ReturnType<typeof getMDXComponents>;
}
