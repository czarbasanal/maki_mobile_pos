import { useEffect, useRef, useState } from 'react';
import { ArrowUpTrayIcon } from '@heroicons/react/24/outline';
import { useProductImport } from './useProductImport';
import { ImportPreviewTable } from './ImportPreviewTable';
import { LoadingView } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';

export function ProductImportPage() {
  const {
    isLoadingRefs,
    loadError,
    state,
    parseError,
    summary,
    result,
    isImporting,
    parseFile,
    setAction,
    runImport,
    reset,
  } = useProductImport();
  const fileRef = useRef<HTMLInputElement>(null);
  const [fileName, setFileName] = useState<string | null>(null);

  useEffect(() => {
    document.title = 'Import products · MAKI POS Admin';
  }, []);

  const actionable = summary.insert + summary.update;

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          Import products
        </h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Upload a CSV (name, category, code, price, qty, unit, reorder_level, supplier). SKU is
          generated; cost is decoded from the code.
        </p>
      </header>

      {loadError ? (
        <ErrorView title="Could not load reference data" message={loadError.message} />
      ) : (
        <>
          <div className="flex flex-wrap items-center gap-tk-md">
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

          {parseError ? <ErrorView title="Import error" message={parseError} /> : null}

          {state?.headerError ? (
            <ErrorView title="Wrong columns" message={state.headerError} />
          ) : null}

          {result ? (
            <div className="rounded-md border border-light-hairline bg-light-card p-tk-lg text-bodySmall">
              <p className="font-semibold text-light-text">Import complete</p>
              <p className="mt-tk-xs text-light-text-secondary">
                Inserted {result.inserted} · Updated {result.updated} · Failed {result.failed.length}
              </p>
              {result.failed.length > 0 ? (
                <ul className="mt-tk-sm list-disc pl-tk-lg text-error-dark">
                  {result.failed.map((f) => (
                    <li key={f.row}>Row {f.row}: {f.message}</li>
                  ))}
                </ul>
              ) : null}
              <button
                type="button"
                onClick={() => {
                  reset();
                  setFileName(null);
                }}
                className="mt-tk-md rounded-md border border-light-border px-tk-md py-[6px] text-light-text hover:bg-light-subtle"
              >
                Import another file
              </button>
            </div>
          ) : state && !state.headerError ? (
            <>
              <div className="flex flex-wrap items-center justify-between gap-tk-md">
                <p className="text-bodySmall text-light-text-secondary">
                  {summary.total} rows · {summary.insert} insert · {summary.update} update ·{' '}
                  {summary.skip} skip
                  {summary.errors > 0 ? ` · ${summary.errors} error` : ''}
                </p>
                <button
                  type="button"
                  disabled={actionable === 0 || isImporting}
                  onClick={() => void runImport()}
                  className="rounded-md bg-light-text px-tk-lg py-[8px] text-bodySmall font-semibold text-light-card hover:opacity-90 disabled:opacity-50"
                >
                  {isImporting ? 'Importing…' : `Import ${actionable} product${actionable === 1 ? '' : 's'}`}
                </button>
              </div>
              <ImportPreviewTable rows={state.rows} actions={state.actions} onAction={setAction} />
            </>
          ) : isLoadingRefs ? (
            <div className="h-24">
              <LoadingView label="Loading products & suppliers…" />
            </div>
          ) : null}
        </>
      )}
    </div>
  );
}
