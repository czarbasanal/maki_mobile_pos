// Used for routes that haven't been migrated yet. As each phase lands, the
// route in routes.tsx swaps from this placeholder to the real feature page.

import { EmptyState } from './EmptyState';

export function PagePlaceholder({ title, phase }: { title: string; phase?: string }) {
  return (
    <div className="p-tk-xl">
      <header className="mb-tk-lg">
        <h1 className="text-headingMedium font-semibold text-light-text">{title}</h1>
      </header>
      <EmptyState
        title="Not migrated yet"
        description={
          phase
            ? `This route lands in ${phase}. The Flutter web build still serves it for now.`
            : 'This route hasn’t been migrated to React yet. The Flutter web build still serves it for now.'
        }
      />
    </div>
  );
}
