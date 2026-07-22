// /hr/payslips — placeholder. Real payslip list lands in a later task of the
// HR/payroll epic.

import { useEffect } from 'react';

export function PayslipsPage() {
  useEffect(() => {
    document.title = 'Payslips · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          Payslips
        </h1>
      </header>
      <p className="text-bodySmall text-light-text-secondary">
        Payslip history is coming in this branch.
      </p>
    </div>
  );
}
