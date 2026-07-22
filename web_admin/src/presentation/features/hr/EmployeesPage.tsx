// /hr/employees — placeholder. Real employee list/CRUD lands in a later task
// of the HR/payroll epic.

import { useEffect } from 'react';

export function EmployeesPage() {
  useEffect(() => {
    document.title = 'Employees · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          Employees
        </h1>
      </header>
      <p className="text-bodySmall text-light-text-secondary">
        Employee management is coming in this branch.
      </p>
    </div>
  );
}
