// /hr/payroll — placeholder. Real payroll run/period workflow lands in a
// later task of the HR/payroll epic.

import { useEffect } from 'react';

export function PayrollPage() {
  useEffect(() => {
    document.title = 'Payroll · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          Payroll
        </h1>
      </header>
      <p className="text-bodySmall text-light-text-secondary">
        Payroll runs are coming in this branch.
      </p>
    </div>
  );
}
