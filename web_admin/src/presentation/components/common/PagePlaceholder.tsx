// Used for routes that haven't been migrated yet. As each phase lands, the
// route in routes.tsx swaps from this placeholder to the real feature page.

import { Construction } from 'lucide-react';
import { EmptyState } from './EmptyState';

export function PagePlaceholder({ title, phase }: { title: string; phase?: string }) {
  return (
    <div className="p-tk-xl">
      <EmptyState
        icon={<Construction className="h-10 w-10" />}
        title={title}
        description={
          phase
            ? `This route will be migrated in ${phase}. The Flutter web build still serves it for now.`
            : 'This route hasn’t been migrated to React yet. The Flutter web build still serves it for now.'
        }
      />
    </div>
  );
}
