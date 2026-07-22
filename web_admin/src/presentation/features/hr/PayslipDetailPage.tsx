// /hr/payslips/:id — placeholder. Real payslip detail/print view lands in a
// later task of the HR/payroll epic.

import { useEffect } from 'react';
import { useParams } from 'react-router-dom';

export function PayslipDetailPage() {
  const { id = '' } = useParams();

  useEffect(() => {
    document.title = 'Payslip · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          Payslip {id}
        </h1>
      </header>
      <p className="text-bodySmall text-light-text-secondary">
        Payslip detail is coming in this branch.
      </p>
    </div>
  );
}
