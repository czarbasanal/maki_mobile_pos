// Receipt-style payslip, per design/design_handoff_payslip (hifi): dark
// header with the yellow MAKI mark, centered employee block, dashed-rule
// attendance chips, earnings/deductions rows, dashed totals, the dark
// NET PAY bar with the brand-yellow label, and the system-generated
// footnote. 380px receipt width (min(380px,100%) per the handoff's
// production note). Inter for text, JetBrains Mono for notes — the two
// faces the handoff names; the rest of the app stays on Roboto.
//
// One deliberate extension beyond the handoff: it defines only present (✓,
// green) and off (—, gray) chips, but a payslip carries an Absences
// deduction, so an indistinguishable absent day would hide the reason money
// was docked. Absent renders on the off chip's gray with an ✗ in the
// deduction red.
import '@fontsource/inter/400.css';
import '@fontsource/inter/500.css';
import '@fontsource/inter/600.css';
import '@fontsource/inter/700.css';
import '@fontsource/inter/800.css';
import '@fontsource/jetbrains-mono/400.css';
import '@fontsource/jetbrains-mono/500.css';

import type { DayStatus, Payslip } from '@/domain/hr/types';
import { formatMoney } from '@/core/utils/money';
import makiLogo from '@/assets/maki_logo_yellow.png';

const INTER = "'Inter', system-ui, sans-serif";
const MONO = "'JetBrains Mono', monospace";

// The mark is drawn as SVG geometry rather than a text glyph. html2canvas
// positions text with fontMetrics.getMetrics(<declared font stack>) but fills
// it at the range-measured rect; the declared stack ('Inter', system-ui) is
// never actually loaded and carries no U+2713/U+2717, so the glyph came from a
// system fallback whose metrics disagreed with that baseline — the mark sat
// off-centre in its circle in the downloaded JPG while looking correct in the
// preview. An <svg> is rasterised at its element bounds, so it cannot drift.
const DAY_CHIP: Record<DayStatus, { bg: string; fg: string; path: string }> = {
  // Paths are drawn in a 24x24 box, stroked and centred on that box's middle.
  present: { bg: '#e8f0ec', fg: '#2f7d5b', path: 'M7 12.5l3.5 3.5L17 8.5' },
  dayOff: { bg: '#f0f1f1', fg: '#b0b6b6', path: 'M7.5 12h9' },
  absent: { bg: '#f0f1f1', fg: '#b23b3b', path: 'M8 8l8 8M16 8l-8 8' },
};

const DAY_LABEL: Record<DayStatus, string> = {
  present: 'Present',
  dayOff: 'Day off',
  absent: 'Absent',
};

function DayMark({ status }: { status: DayStatus }) {
  const chip = DAY_CHIP[status];
  return (
    <svg
      data-day-mark={status}
      viewBox="0 0 24 24"
      width="24"
      height="24"
      role="img"
      aria-label={DAY_LABEL[status]}
      style={{ display: 'block' }}
    >
      <path
        d={chip.path}
        fill="none"
        stroke={chip.fg}
        strokeWidth="2.4"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

const WEEKDAY_LABEL = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

function parseIsoLocal(iso: string): Date {
  const [y, m, d] = iso.split('-').map(Number);
  return new Date(y, m - 1, d);
}

function periodLabel(periodStart: string, periodEnd: string): string {
  const start = parseIsoLocal(periodStart).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
  });
  const end = parseIsoLocal(periodEnd).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });
  return `${start} – ${end}`;
}

function generatedDateLabel(createdAt: Date | null): string {
  if (!createdAt) return '—';
  return createdAt.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

interface DeductionRow {
  key: string;
  label: string;
  amount: number;
}

// Standard deduction lines are omitted when zero; every `others` row renders
// regardless (it was deliberately added, unlike an unused standard field).
function deductionRows(payslip: Payslip): DeductionRow[] {
  const d = payslip.inputs.deductions;
  const standard: DeductionRow[] = [
    { key: 'sss', label: 'SSS', amount: d.sss },
    { key: 'philhealth', label: 'PhilHealth', amount: d.philhealth },
    { key: 'pagibig', label: 'Pag-IBIG', amount: d.pagibig },
    { key: 'late', label: 'Late', amount: d.late },
    { key: 'absences', label: 'Absences', amount: d.absences },
    { key: 'cashAdvance', label: 'Cash advance', amount: d.cashAdvance },
  ].filter((row) => row.amount !== 0);
  const others: DeductionRow[] = d.others.map((o, i) => ({
    key: `other-${i}`,
    label: o.label,
    amount: o.amount,
  }));
  return [...standard, ...others];
}

export function PayslipCard({ payslip }: { payslip: Payslip }) {
  const { inputs, computed } = payslip;
  const rows = deductionRows(payslip);

  return (
    <div
      className="w-[380px] max-w-full overflow-hidden rounded-[14px] bg-white shadow-[0_20px_50px_-20px_rgba(18,28,29,.45),0_2px_8px_rgba(18,28,29,.08)]"
      style={{ fontFamily: INTER }}
    >
      {/* Header — dark bar with the yellow mark */}
      <header className="flex items-center gap-[14px] bg-[#121c1d] px-[28px] pb-[20px] pt-[22px]">
        <img src={makiLogo} alt="Maki" className="h-10 w-10 shrink-0 object-contain" />
        <div className="flex flex-col gap-[2px]">
          <div className="text-[13px] font-bold leading-[1.15] tracking-[.01em] text-white">
            MAKI MOTORCYCLE PARTS
            <br />
            &amp; ACCESSORIES SHOP
          </div>
          <div className="mt-[1px] text-[10px] font-medium tracking-[.02em] text-[#9aa5a6]">
            Buanoy, Balamban, Cebu
          </div>
        </div>
      </header>

      <div className="px-[28px] pb-[20px] pt-[24px]">
        {/* Employee */}
        <div className="mb-[20px] text-center">
          <div className="mb-[6px] text-[11px] font-semibold uppercase tracking-[.14em] text-[#8a9192]">
            Payslip
          </div>
          <div className="text-[19px] font-bold leading-[1.2] text-[#121c1d]">
            {payslip.employeeName}
          </div>
          <div className="mt-[4px] text-[13px] text-[#6b7273]">
            {periodLabel(payslip.periodStart, payslip.periodEnd)}
          </div>
        </div>

        {/* Attendance */}
        <div className="mb-[20px] border-y border-dashed border-[#cfd3d3] py-[14px]">
          <div className="mb-[12px] text-center text-[10px] font-semibold uppercase tracking-[.14em] text-[#8a9192]">
            Attendance
          </div>
          <div className="grid grid-cols-7 gap-[2px] text-center">
            {payslip.days.map((day) => {
              const chip = DAY_CHIP[day.status];
              return (
                <div key={day.date} className="flex flex-col items-center gap-[6px]">
                  <div className="text-[10px] font-semibold tracking-[.04em] text-[#8a9192]">
                    {WEEKDAY_LABEL[parseIsoLocal(day.date).getDay()]}
                  </div>
                  <div
                    className="h-6 w-6 overflow-hidden rounded-full"
                    style={{ background: chip.bg }}
                  >
                    <DayMark status={day.status} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Earnings */}
        <div className="mb-[10px] text-[10px] font-bold uppercase tracking-[.14em] text-[#8a9192]">
          Earnings
        </div>
        <div className="mb-[18px] flex flex-col gap-[9px]">
          <Row
            label="Base Pay"
            note={`${inputs.hoursWorked}h × ${formatMoney(computed.hourlyRate)}/hr`}
            value={formatMoney(computed.basePay)}
          />
          <Row label="Overtime" value={formatMoney(computed.overtimePay)} />
          <Row label="Holiday Pay" value={formatMoney(computed.holidayPay)} />
          <Row label="Incentives" value={formatMoney(inputs.incentives)} />
        </div>

        {/* Deductions */}
        {rows.length > 0 ? (
          <>
            <div className="mb-[10px] text-[10px] font-bold uppercase tracking-[.14em] text-[#8a9192]">
              Deductions
            </div>
            <div className="mb-[18px] flex flex-col gap-[9px]">
              {rows.map((row) => (
                <Row key={row.key} label={row.label} value={formatMoney(row.amount)} deduction />
              ))}
            </div>
          </>
        ) : null}

        {/* Totals */}
        <div className="mb-[16px] flex flex-col gap-[8px] border-t border-dashed border-[#cfd3d3] pt-[14px]">
          <div className="flex justify-between text-[14px] text-[#4a5152]">
            <span>Gross</span>
            <span className="tabular-nums">{formatMoney(computed.gross)}</span>
          </div>
          <div className="flex justify-between text-[14px] text-[#4a5152]">
            <span>Total Deductions</span>
            <span className="tabular-nums">{`– ${formatMoney(computed.totalDeductions)}`}</span>
          </div>
        </div>

        {/* Net pay bar. Both spans get the SAME fixed 23px line box:
            html2canvas (the Download JPG path) computes baselines from each
            span's own line-height, so the browser's items-center of a 12px
            label next to a 23px figure renders vertically off-center in the
            exported image unless the line boxes match. */}
        <div className="flex items-center justify-between rounded-[10px] bg-[#121c1d] px-[18px] py-[16px]">
          {/* data-export-shift-y: harness-calibrated half-pixel lift for the
              JPG export (clone-only; see downloadJpg.ts). */}
          <span
            data-export-shift-y="-0.5"
            className="text-[12px] font-bold uppercase leading-[23px] tracking-[.14em] text-[#f5b921]"
          >
            NET PAY
          </span>
          <span className="text-[23px] font-extrabold leading-[23px] tabular-nums text-white">
            {formatMoney(computed.net)}
          </span>
        </div>
      </div>

      {/* Footer */}
      <footer className="border-t border-dashed border-[#cfd3d3] px-[28px] pb-[22px] pt-[16px] text-center">
        <div className="mb-[4px] text-[12px] text-[#6b7273]">
          Generated {generatedDateLabel(payslip.createdAt)}
        </div>
        <div className="text-[10.5px] tracking-[.04em] text-[#a3a9a9]" style={{ fontFamily: MONO }}>
          This is a System-Generated payslip. No signature required.
        </div>
      </footer>
    </div>
  );
}

function Row({
  label,
  note,
  value,
  deduction = false,
}: {
  label: string;
  note?: string;
  value: string;
  deduction?: boolean;
}) {
  return (
    <div className="flex items-baseline justify-between gap-[12px]">
      <span className="text-[14px] text-[#1e2829]">
        {label}
        {note ? (
          <span className="ml-[6px] text-[11px] text-[#9aa0a0]" style={{ fontFamily: MONO }}>
            {note}
          </span>
        ) : null}
      </span>
      <span
        className="whitespace-nowrap text-[14px] font-medium tabular-nums"
        style={{ color: deduction ? '#b23b3b' : '#1e2829' }}
      >
        {value}
      </span>
    </div>
  );
}
