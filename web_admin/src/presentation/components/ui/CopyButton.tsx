// Copy affordance for machine identifiers (spec §5.7). Sits beside every
// sale no., JO no., SKU, supplier code and batch/serial across the admin.
import type { MouseEvent } from 'react';
import { Square2StackIcon } from '@heroicons/react/24/outline';
import { IconButton } from './IconButton';
import { toast } from './toast';

export function CopyButton({ value, label }: { value: string; label: string }) {
  async function handleClick(event: MouseEvent<HTMLButtonElement>) {
    event.stopPropagation();
    try {
      await navigator.clipboard.writeText(value);
      toast.success('Copied to clipboard', value);
    } catch {
      toast.error('Copy failed', value);
    }
  }

  return (
    <IconButton title={`Copy ${label}`} onClick={handleClick}>
      <Square2StackIcon className="h-[13px] w-[13px]" />
    </IconButton>
  );
}
