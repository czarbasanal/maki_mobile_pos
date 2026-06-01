import { useEffect, useRef, useState } from 'react';
import { ArrowUpTrayIcon } from '@heroicons/react/24/outline';
import { useBulkReceiving } from './useBulkReceiving';
import { ReceivingPreviewTable } from './ReceivingPreviewTable';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';

export function BulkReceivingPage() {
  const {
    isLoadingRefs, loadError, suppliers, supplierId, setSupplierId, state, parseError,
    summary, result, isReceiving, parseFile, reset, runReceive,
  } = useBulkReceiving();
  const fileRef = useRef<HTMLInputElement>(null);
  const [fileName, setFileName] = useState<string | null>(null);

  useEffect(() => {
    document.title = 'Bulk receiving · MAKI POS Admin';
  }, []);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">Bulk receiving</h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Upload a CSV (sku, name, category, unit, cost, price, quantity, reorder_level). Existing SKUs
          get stock added; a different cost spawns a variation; new SKUs (or "GENERATE") are created.
        </p>
      </header>

      {loadError ? (
        <ErrorView title="Could not load reference data" message={loadError.message} />
      ) : (
        <>
          <div className="flex flex-wrap items-center gap-tk-md">
            <select
              className="rounded-md border border-light-border bg-light-card px-tk-md py-[8px] text-bodySmall text-light-text outline-none focus:border-light-text"
              value={supplierId}
              onChange={(e) => setSupplierId(e.target.value)}
            >
              <option value="">No supplier</option>
              {suppliers.map((s) => (
                <option key={s.id} value={s.id}>{s.name}</option>
              ))}
            </select>
            <button
              type="button"
              disabled={isLoadingRefs}
              onClick={() => fileRef.current?.click()}
              className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-md py-[8px] text-bodySmall text-light-text hover:bg-light-subtle disabled:opacity-50"
            >
              <ArrowUpTrayIcon className="h-4 w-4" />
              Choose CSV
            </button>
            {fileName ? <span className="text-bodySmall text-light-text-secondary">{fileName}</span> : null}
            {isLoadingRefs ? <span className="text-bodySmall text-light-text-hint">Loading…</span> : null}
            <input
              ref={fileRef}
              type="file"
              accept=".csv,text/csv"
              className="hidden"
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) {
                  setFileName(f.name);
                  void parseFile(f);
                }
                e.target.value = '';
              }}
            />
          </div>

          {parseError ? <ErrorView title="Receiving error" message={parseError} /> : null}
          {state?.headerError ? <ErrorView title="Wrong columns" message={state.headerError} /> : null}

          {result ? (
            <div className="rounded-md border border-light-hairline bg-light-card p-tk-lg text-bodySmall">
              <p className="font-semibold text-light-text">Received — {result.referenceNumber}</p>
              <p className="mt-tk-xs text-light-text-secondary">
                {result.received} line items · {result.newProducts} new · {result.variations} variations ·
                {' '}{result.failed.length} failed
              </p>
              {result.failed.length > 0 ? (
                <ul className="mt-tk-sm list-disc pl-tk-lg text-error-dark">
                  {result.failed.map((f) => <li key={f.row}>Row {f.row}: {f.message}</li>)}
                </ul>
              ) : null}
              <button
                type="button"
                onClick={() => { reset(); setFileName(null); }}
                className="mt-tk-md rounded-md border border-light-border px-tk-md py-[6px] text-light-text hover:bg-light-subtle"
              >
                Receive another file
              </button>
            </div>
          ) : state && !state.headerError ? (
            <>
              <div className="flex flex-wrap items-center justify-between gap-tk-md">
                <p className="text-bodySmall text-light-text-secondary">
                  {summary.total} rows · {summary.new} new · {summary.match} match · {summary.mismatch} variation
                  {summary.errors > 0 ? ` · ${summary.errors} error` : ''}
                </p>
                <button
                  type="button"
                  disabled={summary.actionable === 0 || isReceiving}
                  onClick={() => void runReceive()}
                  className="rounded-md bg-light-text px-tk-lg py-[8px] text-bodySmall font-semibold text-light-card hover:opacity-90 disabled:opacity-50"
                >
                  {isReceiving ? 'Receiving…' : `Receive ${summary.actionable} item${summary.actionable === 1 ? '' : 's'}`}
                </button>
              </div>
              <ReceivingPreviewTable rows={state.rows} />
            </>
          ) : isLoadingRefs ? (
            <div className="h-24"><LoadingView label="Loading products & suppliers…" /></div>
          ) : null}
        </>
      )}
    </div>
  );
}
