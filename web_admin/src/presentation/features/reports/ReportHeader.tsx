// The row every report screen opens with (reports guide §3):
//   [back to Reports] ............ [date range | daily lock] [CSV]
// Same place on all four so the control never has to be hunted for.
import { useLocation, useNavigate } from 'react-router-dom';
import { ArrowDownTrayIcon } from '@heroicons/react/24/outline';
import { RoutePaths } from '@/presentation/router/routePaths';
import { BackButton } from '@/presentation/components/ui/BackButton';
import { Button } from '@/presentation/components/ui/Button';
import { DateRangeControl } from '@/presentation/components/ui/DateRangeControl';
import { DailyLockNotice } from './DailyLockNotice';
import { REPORT_RANGE_OPTIONS, type ReportRangeState } from './useReportRange';

export function ReportRangeControl({ range }: { range: ReportRangeState }) {
  return (
    <DateRangeControl
      options={REPORT_RANGE_OPTIONS}
      value={range.preset}
      onChange={range.setPreset}
      customStart={range.customStart}
      customEnd={range.customEnd}
      onCustomStart={range.setCustomStart}
      onCustomEnd={range.setCustomEnd}
    />
  );
}

export function ReportHeader({
  range,
  lock,
  onExport,
  exportDisabled = false,
  back = true,
}: {
  range: ReportRangeState;
  /** Daily-only copy; when set, replaces the range control. */
  lock?: string;
  onExport?: () => void;
  exportDisabled?: boolean;
  /** The index has nothing to go back to. */
  back?: boolean;
}) {
  const navigate = useNavigate();
  const { search } = useLocation();
  return (
    <div className="flex flex-wrap items-center gap-2.5">
      {back ? (
        // Back keeps the range: the index re-opens on the scope the report was read at.
        <BackButton label="Reports" onClick={() => navigate({ pathname: RoutePaths.reports, search })} />
      ) : null}
      <div className="ml-auto flex items-center gap-[9px]">
        {lock ? <DailyLockNotice>{lock}</DailyLockNotice> : <ReportRangeControl range={range} />}
        {onExport ? (
          <Button
            variant="secondary"
            title="Download CSV"
            icon={<ArrowDownTrayIcon className="h-3.5 w-3.5" />}
            onClick={onExport}
            disabled={exportDisabled}
          >
            CSV
          </Button>
        ) : null}
      </div>
    </div>
  );
}
