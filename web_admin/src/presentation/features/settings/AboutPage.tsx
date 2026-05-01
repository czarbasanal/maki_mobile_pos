// /admin/settings/about — version + tech info. Trimmed compared to the
// Flutter version (no support links — the email is fictional anyway).

import { useEffect } from 'react';
import { PageHeader } from './PageHeader';

const APP_VERSION = '1.0.0';
const TECHNICAL_INFO: Array<[string, string]> = [
  ['Platform', 'React + TypeScript'],
  ['Bundler', 'Vite 6'],
  ['Backend', 'Firebase (Auth + Firestore + Storage)'],
  ['Currency', 'Philippine Peso (₱)'],
  ['Project', 'maki-mobile-pos'],
];

export function AboutPage() {
  useEffect(() => {
    document.title = 'About · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <PageHeader title="About" description="Version and technical information." />

      <section className="flex flex-col items-center gap-tk-md rounded-lg border border-light-hairline bg-light-card p-tk-xl text-center">
        <span className="grid h-16 w-16 place-items-center rounded-md border border-light-border text-[26px] font-semibold leading-none text-light-text">
          M
        </span>
        <div>
          <div className="text-bodyLarge font-semibold tracking-tight text-light-text">
            MAKI POS Admin
          </div>
          <div className="mt-tk-xs text-bodySmall text-light-text-secondary">
            Version {APP_VERSION}
          </div>
        </div>
      </section>

      <section className="space-y-tk-sm">
        <h2 className="text-[11px] font-semibold uppercase tracking-wider text-light-text-hint">
          About this app
        </h2>
        <div className="rounded-lg border border-light-hairline bg-light-card p-tk-md">
          <p className="text-bodySmall text-light-text-secondary">
            A web admin for the MAKI POS system, used for inventory management, sales reporting,
            and store administration. Sales transactions are entered through the mobile POS app
            and synchronised in real time via Firestore.
          </p>
        </div>
      </section>

      <section className="space-y-tk-sm">
        <h2 className="text-[11px] font-semibold uppercase tracking-wider text-light-text-hint">
          Technical
        </h2>
        <dl className="overflow-hidden rounded-lg border border-light-hairline bg-light-card divide-y divide-light-hairline">
          {TECHNICAL_INFO.map(([label, value]) => (
            <div key={label} className="flex items-center justify-between px-tk-md py-tk-sm">
              <dt className="text-bodySmall text-light-text-secondary">{label}</dt>
              <dd className="text-bodySmall font-medium text-light-text">{value}</dd>
            </div>
          ))}
        </dl>
      </section>

      <p className="text-center text-[11px] tracking-[0.5px] text-light-text-hint">
        © {new Date().getFullYear()} MAKI POS · All rights reserved
      </p>
    </div>
  );
}
