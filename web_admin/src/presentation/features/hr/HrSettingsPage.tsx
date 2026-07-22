// /hr/settings — placeholder. Real HR settings (week start day, holiday pay
// percentages) land in a later task of the HR/payroll epic.

import { useEffect } from 'react';

export function HrSettingsPage() {
  useEffect(() => {
    document.title = 'HR Settings · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          HR Settings
        </h1>
      </header>
      <p className="text-bodySmall text-light-text-secondary">
        HR settings are coming in this branch.
      </p>
    </div>
  );
}
