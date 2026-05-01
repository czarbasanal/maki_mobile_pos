import { Loader2 } from 'lucide-react';

export function LoadingView({ label = 'Loading…' }: { label?: string }) {
  return (
    <div className="flex h-full w-full items-center justify-center p-tk-xl text-light-text-secondary">
      <Loader2 className="mr-tk-sm h-5 w-5 animate-spin" />
      <span>{label}</span>
    </div>
  );
}
