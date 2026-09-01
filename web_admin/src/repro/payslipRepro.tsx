// DEV-ONLY harness page (payslip-repro.html) — renders the real PayslipCard
// and the real html2canvas export pipeline side by side so the JPG's text
// placement can be measured headlessly. Not part of the production build
// (vite only builds index.html).
import { useEffect, useRef } from 'react';
import { createRoot } from 'react-dom/client';
import { PayslipCard } from '@/presentation/features/hr/PayslipCard';
import { renderElementToCanvas } from '@/core/utils/downloadJpg';
import type { Payslip } from '@/domain/hr/types';
import '../index.css';

const payslip: Payslip = {
  id: 'p1',
  employeeId: 'e1',
  employeeName: 'Juan Dela Cruz',
  periodStart: '2026-08-24',
  periodEnd: '2026-08-30',
  days: [
    { date: '2026-08-24', status: 'present' },
    { date: '2026-08-25', status: 'present' },
    { date: '2026-08-26', status: 'dayOff' },
  ],
  inputs: {
    hoursWorked: 48,
    dailyRate: 400,
    overtimeHours: 0,
    overtimeRatePerHour: 0,
    regularHolidayDays: 0,
    specialHolidayDays: 0,
    regularHolidayPct: 100,
    specialHolidayPct: 30,
    incentives: 80,
    deductions: { sss: 0, philhealth: 0, pagibig: 0, late: 0, absences: 0, cashAdvance: 75, others: [] },
  },
  computed: {
    hourlyRate: 50,
    basePay: 2400,
    overtimePay: 0,
    holidayPay: 0,
    gross: 2480,
    totalDeductions: 75,
    net: 2405,
  },
  createdAt: new Date('2026-08-31T10:00:00Z'),
  createdBy: 'u1',
  createdByName: 'Admin',
};

declare global {
  interface Window {
    reproReady?: boolean;
  }
}

function Repro() {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    (async () => {
      await document.fonts.ready;
      await new Promise((r) => setTimeout(r, 500));
      const canvas = await renderElementToCanvas(ref.current!);
      const img = new Image();
      img.src = canvas.toDataURL('image/png');
      img.style.width = `${ref.current!.offsetWidth}px`;
      document.getElementById('out')!.appendChild(img);
      window.reproReady = true;
    })();
  }, []);
  return (
    <div style={{ padding: 20, background: '#fff' }}>
      <div ref={ref} id="card-live" style={{ width: 420 }}>
        <PayslipCard payslip={payslip} />
      </div>
      <div style={{ font: '12px monospace', margin: '12px 0' }}>export ↓</div>
      <div id="out" />
    </div>
  );
}

createRoot(document.getElementById('root')!).render(<Repro />);
