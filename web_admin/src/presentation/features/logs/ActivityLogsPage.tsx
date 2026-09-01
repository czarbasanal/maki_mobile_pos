// /admin/logs — read-only audit trail. Mirrors the Flutter
// activity_logs_screen: nothing is fetched on open; the admin picks
// operations plus a date/time window and taps Search, which issues a single
// capped read. Results are a frozen snapshot, grouped by date.

import { useEffect, useMemo, useState, type ComponentType, type SVGProps } from 'react';
import {
  ArrowPathIcon,
  ArrowRightOnRectangleIcon,
  ArrowUturnLeftIcon,
  BookOpenIcon,
  BuildingStorefrontIcon,
  ClipboardDocumentListIcon,
  Cog6ToothIcon,
  CodeBracketSquareIcon,
  CubeIcon,
  CurrencyDollarIcon,
  ExclamationTriangleIcon,
  EyeIcon,
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
import { ActivityLogFilterBar } from './ActivityLogFilterBar';
import {
  ACTIVITY_LOG_SEARCH_LIMIT,
  useActivityLogSearch,
} from '@/presentation/hooks/useActivityLogSearch';
import { resolvePreset, type DateRange } from '@/domain/reports/dateRange';
import {
  getAmbientShopTimezone,
  instantOf,
  shopDayInt,
  shopIsoDate,
  shopTimeOf,
  shopWall,
} from '@/domain/time/shopTime';
import type { ActivityLogQuery } from '@/domain/repositories/ActivityLogRepository';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { EmptyState } from '@/presentation/components/common/EmptyState';
import { CappedNotice } from '@/presentation/components/common/CappedNotice';
import { Pager } from '@/presentation/components/common/Pager';
import { usePageClamp } from '@/presentation/hooks/usePageClamp';
import { usePageSize } from '@/presentation/hooks/usePageSize';
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
  day_closed: BookOpenIcon,
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
      return 'yellow';
    case ActivityType.dayClosed:
      return 'orange';
    default:
      return 'blue';
  }
}

// Rendered in the shop's zone so the day header, the grouping, and the row
// time all agree — a browser elsewhere would otherwise split one shop day
// across two headers.
const dateGroupFmt = new Intl.DateTimeFormat('en-PH', {
  weekday: 'long',
  month: 'long',
  day: 'numeric',
  year: 'numeric',
  timeZone: getAmbientShopTimezone().timezoneId,
});

const timeFmt = new Intl.DateTimeFormat('en-PH', {
  hour: 'numeric',
  minute: '2-digit',
  hour12: true,
  timeZone: getAmbientShopTimezone().timezoneId,
});

function dayKey(d: Date): string {
  return shopIsoDate(d);
}

function isSameShopDay(a: Date, b: Date): boolean {
  return shopDayInt(a) === shopDayInt(b);
}

function dateLabel(d: Date): string {
  const now = new Date();
  if (isSameShopDay(d, now)) return 'Today';
  if (isSameShopDay(d, new Date(now.getTime() - 86_400_000))) return 'Yesterday';
  return dateGroupFmt.format(d);
}

export function ActivityLogsPage() {
  const [types, setTypes] = useState<ActivityType[]>([]);
  const [range, setRange] = useState<DateRange>(() => resolvePreset('today'));
  const [startTime, setStartTime] = useState('00:00');
  const [endTime, setEndTime] = useState('23:59');
  const [dirty, setDirty] = useState(false);
  // The query the admin actually submitted. Held so Refresh replays THAT
  // window rather than whatever the filter controls happen to read right now
  // — mirrors the mobile screen's `_submitted`.
  const [submitted, setSubmitted] = useState<ActivityLogQuery | null>(null);
  const searched = submitted !== null;
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = usePageSize('activityLogs');
  const { data: logs, isLoading, error, run } = useActivityLogSearch();
  usePageClamp(page, setPage, logs?.length ?? 0, pageSize);

  useEffect(() => {
    document.title = 'Activity logs · MAKI POS Admin';
  }, []);

  const startAt = applyTime(range.start, startTime, false);
  const endAt = applyTime(range.end, endTime, true);
  // Either bound failing to parse (e.g. a cleared time input) is just as
  // invalid as start-after-end — neither is a safe query to run.
  const rangeInvalid = startAt === null || endAt === null || startAt.getTime() > endAt.getTime();

  function markDirty() {
    if (searched) setDirty(true);
  }

  function onSearch() {
    // Local guard so this invariant doesn't depend on the child button's
    // `disabled` prop being wired correctly.
    if (rangeInvalid || startAt === null || endAt === null) return;
    const query: ActivityLogQuery = {
      types,
      start: startAt,
      end: endAt,
      limit: ACTIVITY_LOG_SEARCH_LIMIT,
    };
    setSubmitted(query);
    setDirty(false);
    setPage(1);
    void run(query);
  }

  // Same search, fresh rows. Deliberately leaves `dirty` alone: any filter
  // edit the admin has made is still unsubmitted, so the "tap Search" prompt
  // must survive a Refresh.
  function onRefresh() {
    if (!submitted) return;
    setPage(1);
    void run(submitted);
  }

  const pagedLogs = useMemo(
    () => (logs ?? []).slice((page - 1) * pageSize, page * pageSize),
    [logs, page, pageSize],
  );

  // Paginate the flat list BEFORE grouping by date, so each page's date
  // groups are coherent (a group never spans across a page boundary).
  const grouped = useMemo(() => {
    const groups = new Map<string, { date: Date; logs: ActivityLog[] }>();
    for (const log of pagedLogs) {
      const key = dayKey(log.createdAt);
      const existing = groups.get(key);
      if (existing) {
        existing.logs.push(log);
      } else {
        groups.set(key, {
          // Group-header date carries the SHOP (PHT) calendar day, not the
          // viewer's — same day boundaries as every report.
          date: (() => {
            const wall = shopTimeOf(log.createdAt);
            return new Date(wall.getUTCFullYear(), wall.getUTCMonth(), wall.getUTCDate());
          })(),
          logs: [log],
        });
      }
    }
    return Array.from(groups.values());
  }, [pagedLogs]);

  return (
    <div className="space-y-tk-xl">
      <header className="space-y-tk-md">
        {searched && logs ? (
          <div className="flex justify-end">
            <button
              type="button"
              onClick={onRefresh}
              className="rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Refresh
            </button>
          </div>
        ) : null}
        <ActivityLogFilterBar
          types={types}
          onTypes={(next) => {
            setTypes(next);
            markDirty();
          }}
          onRange={(next) => {
            setRange(next);
            markDirty();
          }}
          startTime={startTime}
          endTime={endTime}
          onStartTime={(v) => {
            setStartTime(v);
            markDirty();
          }}
          onEndTime={(v) => {
            setEndTime(v);
            markDirty();
          }}
          dirty={dirty}
          disabled={rangeInvalid}
          onSearch={onSearch}
        />
      </header>

      {!searched ? (
        <EmptyState
          title="Pick your filters and tap Search."
          description="Choose the operations and the date and time range you want to review, then tap Search."
        />
      ) : error ? (
        <ErrorView title="Could not load logs" message={error.message} />
      ) : isLoading || !logs ? (
        <LoadingView label="Loading logs…" />
      ) : grouped.length === 0 ? (
        <EmptyState
          title="No activity matched these filters"
          description="Try a wider date range, or fewer operations."
        />
      ) : (
        <div className="space-y-tk-lg">
          <CappedNotice capped={logs.length >= ACTIVITY_LOG_SEARCH_LIMIT}>
            Showing the newest {ACTIVITY_LOG_SEARCH_LIMIT} — narrow your range.
          </CappedNotice>
          {grouped.map((group) => (
            <section key={dayKey(group.date)} className="space-y-tk-sm">
              <h2 className="sticky top-0 z-[1] -mx-7 border-b border-light-hairline bg-light-background/80 px-7 py-tk-xs text-[11px] font-semibold uppercase tracking-wider text-light-text-secondary backdrop-blur">
                {dateLabel(group.date)}
              </h2>
              <ul className="overflow-hidden rounded-lg border border-light-hairline bg-light-card divide-y divide-light-hairline">
                {group.logs.map((log) => (
                  <LogRow key={log.id} log={log} />
                ))}
              </ul>
            </section>
          ))}
          <Pager total={logs.length} page={page} onPage={setPage} pageSize={pageSize}
            onPageSize={(n) => { setPageSize(n); setPage(1); }} />
        </div>
      )}
    </div>
  );
}

/**
 * Parses a strict 24-hour `HH:MM` string, the shape a native
 * `<input type="time">` reports. Returns `null` for anything that isn't a
 * well-formed time — including the empty string a cleared input produces —
 * so callers can't mistake "nothing entered" for midnight.
 */
function parseTime(hhmm: string): { h: number; m: number } | null {
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(hhmm);
  if (!match) return null;
  return { h: Number(match[1]), m: Number(match[2]) };
}

/**
 * Stamps a SHOP wall-clock time onto the shop day containing `day`, and
 * returns the instant. The picked time belongs to the shop clock, so the
 * arithmetic happens on the wall value and converts back — `setHours` would
 * stamp the browser's clock onto a shop-time instant. The end bound is pushed
 * to the last millisecond of the chosen minute so an inclusive `<=` never
 * drops a record logged within it. Returns `null` when `hhmm` doesn't parse.
 */
function applyTime(day: Date, hhmm: string, endInclusive: boolean): Date | null {
  const parsed = parseTime(hhmm);
  if (!parsed) return null;
  const w = shopTimeOf(day);
  return instantOf(
    shopWall(
      w.getUTCFullYear(),
      w.getUTCMonth() + 1,
      w.getUTCDate(),
      parsed.h,
      parsed.m,
      endInclusive ? 59 : 0,
      endInclusive ? 999 : 0,
    ),
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
