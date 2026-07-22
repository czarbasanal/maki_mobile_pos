// Receipt-style payslip. This is a deliberate placeholder layout — monochrome,
// fixed-width — structured (header / attendance row / earnings / deductions /
// totals / NET PAY / footer) so a future design handoff can restyle in place
// without reshaping the markup. Mirrors reports/Receipt.tsx's plain-Line
// idiom.

import type { DayStatus, Payslip } from '@/domain/hr/types';
import { formatMoney } from '@/core/utils/money';

const SHOP_NAME = 'MAKI MOTORCYCLE PARTS & SERVICES';

const DAY_SYMBOL: Record<DayStatus, string> = {
  present: '✓',
  absent: '✗',
  dayOff: 'off',
};

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
    <div className="w-[420px] max-w-full space-y-tk-md bg-white p-tk-lg text-[13px] text-black">
      <header className="space-y-tk-xs text-center">
        <div className="text-[14px] font-bold uppercase tracking-wide">{SHOP_NAME}</div>
        <div className="font-semibold">{payslip.employeeName}</div>
        <div className="text-[12px] text-neutral-600">
          {periodLabel(payslip.periodStart, payslip.periodEnd)}
        </div>
      </header>

      <Divider />

      <section className="grid grid-cols-7 gap-tk-xs text-center text-[11px]">
        {payslip.days.map((day) => (
          <div key={day.date} className="font-semibold">
            {DAY_SYMBOL[day.status]}
          </div>
        ))}
      </section>

      <Divider />

      <section className="space-y-tk-xs">
        <h3 className="text-[11px] font-semibold uppercase tracking-wide">Earnings</h3>
        <Row
          label="Base Pay"
          caption={`${inputs.hoursWorked}h × ${formatMoney(computed.hourlyRate)}/hr`}
          value={formatMoney(computed.basePay)}
        />
        <Row label="Overtime" value={formatMoney(computed.overtimePay)} />
        <Row label="Holiday Pay" value={formatMoney(computed.holidayPay)} />
        <Row label="Incentives" value={formatMoney(inputs.incentives)} />
      </section>

      {rows.length > 0 ? (
        <section className="space-y-tk-xs">
          <h3 className="text-[11px] font-semibold uppercase tracking-wide">Deductions</h3>
          {rows.map((row) => (
            <Row key={row.key} label={row.label} value={formatMoney(row.amount)} />
          ))}
        </section>
      ) : null}

      <Divider />

      <section className="space-y-tk-xs">
        <Row label="Gross" value={formatMoney(computed.gross)} />
        <Row label="Total Deductions" value={formatMoney(computed.totalDeductions)} />
      </section>

      <div className="flex items-baseline justify-between border-t-2 border-black pt-tk-sm text-[16px] font-bold">
        <span>NET PAY</span>
        <span className="tabular-nums">{formatMoney(computed.net)}</span>
      </div>

      <p className="pt-tk-sm text-center text-[10px] text-neutral-500">
        Generated {generatedDateLabel(payslip.createdAt)} · placeholder layout
      </p>
    </div>
  );
}

function Divider() {
  return <div className="border-t border-dashed border-neutral-400" />;
}

function Row({ label, caption, value }: { label: string; caption?: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-tk-sm">
      <span>
        <span>{label}</span>
        {caption ? <span className="ml-tk-xs text-[10px] text-neutral-500">{caption}</span> : null}
      </span>
      <span className="tabular-nums">{value}</span>
    </div>
  );
}
