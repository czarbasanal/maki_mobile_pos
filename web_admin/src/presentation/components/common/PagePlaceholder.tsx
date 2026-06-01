// Used for routes whose feature page isn't built yet. As each one lands, the
// route in routes.tsx swaps from this placeholder to the real feature page.

import { EmptyState } from './EmptyState';

export function PagePlaceholder({ title, phase }: { title: string; phase?: string }) {
  return (
    <div className="p-tk-xl">
      <header className="mb-tk-lg">
        <h1 className="text-headingMedium font-semibold text-light-text">{title}</h1>
      </header>
      <EmptyState
        title="Not available yet"
        description={
          phase
            ? `This section isn't available in the web admin yet (planned: ${phase}). Use the mobile app for now.`
            : "This section isn't available in the web admin yet. Use the mobile app for now."
        }
      />
    </div>
  );
}
