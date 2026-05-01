import type { ReactNode } from 'react';
import { cn } from '@/core/utils/cn';

export interface EmptyStateProps {
  title: string;
  description?: string;
  icon?: ReactNode;
  action?: ReactNode;
  className?: string;
}

export function EmptyState({ title, description, icon, action, className }: EmptyStateProps) {
  return (
    <div
      className={cn(
        'flex flex-col items-center justify-center gap-tk-sm rounded-lg border border-dashed border-light-border p-tk-xl text-center',
        className,
      )}
    >
      {icon ? <div className="text-light-text-secondary">{icon}</div> : null}
      <h3 className="text-headingSmall text-light-text">{title}</h3>
      {description ? (
        <p className="max-w-md text-bodyMedium text-light-text-secondary">{description}</p>
      ) : null}
      {action}
    </div>
  );
}
