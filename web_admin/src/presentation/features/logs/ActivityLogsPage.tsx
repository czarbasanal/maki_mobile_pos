// /admin/logs — read-only audit trail. Mirrors the Flutter
// activity_logs_screen: type filter, date-grouped list, type-tinted icon
// next to each row.

import { useEffect, useMemo, useState, type ComponentType, type SVGProps } from 'react';
import {
  ArrowPathIcon,
  ArrowRightOnRectangleIcon,
  ArrowUturnLeftIcon,
  BanknotesIcon,
  BuildingStorefrontIcon,
  ChevronDownIcon,
  ClipboardDocumentListIcon,
  Cog6ToothIcon,
  CodeBracketSquareIcon,
  CubeIcon,
  CurrencyDollarIcon,
  ExclamationTriangleIcon,
  EyeIcon,
  FunnelIcon,
  KeyIcon,
  LockClosedIcon,
  ReceiptPercentIcon,
  ShieldCheckIcon,
  TruckIcon,
  UserIcon,
  UserMinusIcon,
  UserPlusIcon,
  UsersIcon,
  XCircleIcon,
} from '@heroicons/react/24/outline';
import {
  ActivityType,
  activityTypeDisplayName,
  isFinancialActivity,
  isSecurityActivity,
  type ActivityLog,
} from '@/domain/entities';
import { useActivityLogs } from '@/presentation/hooks/useActivityLogs';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { toneBadgeClasses, type Tone } from '@/core/theme/tones';
import { cn } from '@/core/utils/cn';

const ICONS: Record<ActivityType, ComponentType<SVGProps<SVGSVGElement>>> = {
  authentication: ShieldCheckIcon,
  login: ArrowRightOnRectangleIcon,
  logout: ArrowRightOnRectangleIcon,
  sale: CurrencyDollarIcon,
  void_sale: XCircleIcon,
  refund: ArrowUturnLeftIcon,
  inventory: CubeIcon,
  stock_adjustment: ArrowPathIcon,
  receiving: TruckIcon,
  user_management: UsersIcon,
  user_created: UserPlusIcon,
  user_updated: UserIcon,
  user_deactivated: UserMinusIcon,
  role_changed: KeyIcon,
  security: ShieldCheckIcon,
  password_verified: LockClosedIcon,
  password_failed: ExclamationTriangleIcon,
  cost_viewed: EyeIcon,
  settings: Cog6ToothIcon,
  cost_code_changed: CodeBracketSquareIcon,
  expense: ReceiptPercentIcon,
  supplier: BuildingStorefrontIcon,
  petty_cash: BanknotesIcon,
  petty_cash_cutoff: BanknotesIcon,
  other: ClipboardDocumentListIcon,
};

function toneFor(type: ActivityType): Tone {
  if (isSecurityActivity(type)) return 'red';
  if (isFinancialActivity(type)) return 'green';
  switch (type) {
    case ActivityType.inventory:
    case ActivityType.stockAdjustment:
    case ActivityType.receiving:
      return 'blue';
    case ActivityType.userCreated:
    case ActivityType.userUpdated:
    case ActivityType.userDeactivated:
    case ActivityType.roleChanged:
      return 'violet';
    case ActivityType.settings:
    case ActivityType.costCodeChanged:
      return 'orange';
    case ActivityType.expense:
    case ActivityType.pettyCash:
    case ActivityType.pettyCashCutOff:
      return 'yellow';
    default:
      return 'blue';
  }
}

const COMMON_TYPES: ActivityType[] = [
  ActivityType.login,
  ActivityType.logout,
  ActivityType.sale,
  ActivityType.voidSale,
  ActivityType.stockAdjustment,
  ActivityType.receiving,
  ActivityType.userCreated,
  ActivityType.userUpdated,
  ActivityType.roleChanged,
  ActivityType.passwordVerified,
  ActivityType.passwordFailed,
  ActivityType.costViewed,
  ActivityType.costCodeChanged,
];

const dateGroupFmt = new Intl.DateTimeFormat('en-PH', {
  weekday: 'long',
  month: 'long',
  day: 'numeric',
  year: 'numeric',
});

const timeFmt = new Intl.DateTimeFormat('en-PH', {
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
});

function dayKey(d: Date): string {
  return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
}

function isToday(d: Date): boolean {
  const now = new Date();
  return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth() && d.getDate() === now.getDate();
}

function isYesterday(d: Date): boolean {
  const y = new Date();
  y.setDate(y.getDate() - 1);
  return d.getFullYear() === y.getFullYear() && d.getMonth() === y.getMonth() && d.getDate() === y.getDate();
}

function dateLabel(d: Date): string {
  if (isToday(d)) return 'Today';
  if (isYesterday(d)) return 'Yesterday';
  return dateGroupFmt.format(d);
}

export function ActivityLogsPage() {
  const [type, setType] = useState<ActivityType | null>(null);
  const { data: logs, isLoading, error } = useActivityLogs({
    type: type ?? undefined,
    limit: 200,
  });

  useEffect(() => {
    document.title = 'Activity logs · MAKI POS Admin';
  }, []);

  const grouped = useMemo(() => {
    if (!logs) return [];
    const groups = new Map<string, { date: Date; logs: ActivityLog[] }>();
    for (const log of logs) {
      const key = dayKey(log.createdAt);
      const existing = groups.get(key);
      if (existing) {
        existing.logs.push(log);
      } else {
        groups.set(key, {
          date: new Date(
            log.createdAt.getFullYear(),
            log.createdAt.getMonth(),
            log.createdAt.getDate(),
          ),
          logs: [log],
        });
      }
    }
    return Array.from(groups.values());
  }, [logs]);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header className="flex flex-wrap items-end justify-between gap-tk-md">
        <div>
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            Activity logs
          </h1>
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Real-time audit trail of user actions across both web and mobile clients.
          </p>
        </div>
        <TypeFilter value={type} onChange={setType} />
      </header>

      {error ? (
        <ErrorView title="Could not load logs" message={error.message} />
      ) : isLoading || !logs ? (
        <LoadingView label="Loading logs…" />
      ) : grouped.length === 0 ? (
        <EmptyState
          title="No activity yet"
          description={
            type
              ? `No ${activityTypeDisplayName[type]} entries match this filter.`
              : 'Logs will appear here as users sign in and take actions.'
          }
        />
      ) : (
        <div className="space-y-tk-lg">
          {grouped.map((group) => (
            <section key={dayKey(group.date)} className="space-y-tk-sm">
              <h2 className="sticky top-0 z-[1] -mx-tk-xl border-b border-light-hairline bg-light-background/80 px-tk-xl py-tk-xs text-[11px] font-semibold uppercase tracking-wider text-light-text-secondary backdrop-blur">
                {dateLabel(group.date)}
              </h2>
              <ul className="overflow-hidden rounded-lg border border-light-hairline bg-light-card divide-y divide-light-hairline">
                {group.logs.map((log) => (
                  <LogRow key={log.id} log={log} />
                ))}
              </ul>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}

function TypeFilter({
  value,
  onChange,
}: {
  value: ActivityType | null;
  onChange: (next: ActivityType | null) => void;
}) {
  const [open, setOpen] = useState(false);
  return (
    <div className="relative">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="flex items-center gap-tk-xs rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
      >
        <FunnelIcon className="h-3.5 w-3.5" />
        {value ? activityTypeDisplayName[value] : 'All activities'}
        <ChevronDownIcon className="h-3.5 w-3.5" />
      </button>
      {open ? (
        <>
          {/* click-outside dismiss */}
          <div className="fixed inset-0 z-10" onClick={() => setOpen(false)} />
          <div className="absolute right-0 z-20 mt-tk-xs max-h-80 w-64 overflow-y-auto rounded-md border border-light-hairline bg-light-card shadow-lg">
            <button
              type="button"
              onClick={() => {
                onChange(null);
                setOpen(false);
              }}
              className={cn(
                'flex w-full items-center gap-tk-sm px-tk-md py-tk-sm text-left text-bodySmall hover:bg-light-subtle',
                value === null ? 'font-semibold text-light-text' : 'text-light-text-secondary',
              )}
            >
              All activities
            </button>
            <div className="border-t border-light-hairline" />
            {COMMON_TYPES.map((t) => {
              const Icon = ICONS[t];
              return (
                <button
                  type="button"
                  key={t}
                  onClick={() => {
                    onChange(t);
                    setOpen(false);
                  }}
                  className={cn(
                    'flex w-full items-center gap-tk-sm px-tk-md py-tk-sm text-left text-bodySmall hover:bg-light-subtle',
                    value === t ? 'font-semibold text-light-text' : 'text-light-text',
                  )}
                >
                  <span
                    className={cn(
                      'grid h-6 w-6 shrink-0 place-items-center rounded-md',
                      toneBadgeClasses[toneFor(t)],
                    )}
                  >
                    <Icon className="h-3.5 w-3.5" />
                  </span>
                  {activityTypeDisplayName[t]}
                </button>
              );
            })}
          </div>
        </>
      ) : null}
    </div>
  );
}

function LogRow({ log }: { log: ActivityLog }) {
  const Icon = ICONS[log.type] ?? ClipboardDocumentListIcon;
  return (
    <li className="flex items-start gap-tk-md p-tk-md">
      <span
        className={cn(
          'grid h-9 w-9 shrink-0 place-items-center rounded-md',
          toneBadgeClasses[toneFor(log.type)],
        )}
      >
        <Icon className="h-4 w-4" />
      </span>
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-baseline justify-between gap-tk-sm">
          <span className="text-bodyMedium font-medium text-light-text">
            {log.action || activityTypeDisplayName[log.type]}
          </span>
          <span className="shrink-0 text-[12px] text-light-text-hint">
            {timeFmt.format(log.createdAt)}
          </span>
        </div>
        {log.details ? (
          <p className="mt-tk-xs text-bodySmall text-light-text-secondary">{log.details}</p>
        ) : null}
        <div className="mt-tk-xs flex items-center gap-tk-sm text-[12px] text-light-text-hint">
          <span className="inline-flex items-center gap-tk-xs">
            <UserIcon className="h-3 w-3" />
            {log.userName || '—'}
          </span>
          {log.userRole ? (
            <span className="rounded-full bg-light-subtle px-tk-xs py-[1px] text-[10px] font-semibold uppercase tracking-wider text-light-text-secondary">
              {log.userRole}
            </span>
          ) : null}
        </div>
      </div>
    </li>
  );
}
