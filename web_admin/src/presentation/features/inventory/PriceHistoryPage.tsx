import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useProducts } from '@/presentation/hooks/useProducts';
import type { Product } from '@/domain/entities';
import { PriceHistoryView } from './PriceHistoryView';
import { displaySku } from '@/domain/products/sku';
import { matchesProductQuery } from '@/domain/products/productSearch';

export function PriceHistoryPage() {
  useEffect(() => {
    document.title = 'Price History · MAKI POS Admin';
  }, []);

  const { data: products, isLoading } = useProducts();
  const [queryText, setQueryText] = useState('');
  const [selected, setSelected] = useState<Product | null>(null);

  const [searchParams] = useSearchParams();
  const productIdParam = searchParams.get('product');

  // Deep-link: when arriving via /inventory/price-history?product=<id>, pre-select
  // that product once the list has loaded. Manual search still works afterwards.
  useEffect(() => {
    if (!productIdParam || selected || !products) return;
    const match = products.find((p) => p.id === productIdParam);
    if (match) {
      setSelected(match);
      setQueryText(match.name);
    }
  }, [productIdParam, products, selected]);

  const q = queryText.trim();
  const matches =
    q.length === 0 ? [] : (products ?? []).filter((p) => matchesProductQuery(p, q));

  return (
    <div className="space-y-tk-xl">
      <div className="max-w-md">
        <input
          type="search"
          value={queryText}
          onChange={(ev) => {
            setQueryText(ev.target.value);
            setSelected(null);
          }}
          placeholder="Search by name or SKU…"
          className="w-full rounded-md border border-light-hairline bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
        />
        {!selected && matches.length > 0 ? (
          <ul className="mt-tk-xs max-h-64 overflow-y-auto rounded-md border border-light-hairline bg-light-card">
            {matches.map((p) => (
              <li key={p.id}>
                <button
                  type="button"
                  onClick={() => {
                    setSelected(p);
                    setQueryText(p.name);
                  }}
                  className="flex w-full items-center justify-between px-tk-md py-tk-sm text-left text-bodySmall hover:bg-light-subtle"
                >
                  <span className="text-light-text">{p.name}</span>
                  <span className="text-light-text-hint">{displaySku(p.sku)}</span>
                </button>
              </li>
            ))}
          </ul>
        ) : null}
      </div>

      {isLoading ? (
        <p className="text-bodySmall text-light-text-secondary">Loading products…</p>
      ) : null}

      {selected ? (
        <section className="space-y-tk-md">
          <button
            type="button"
            onClick={() => {
              setSelected(null);
              setQueryText('');
            }}
            className="text-bodySmall text-light-text-secondary hover:underline"
          >
            ← Back
          </button>
          <div>
            <h2 className="text-bodyMedium font-semibold text-light-text">{selected.name}</h2>
            <p className="text-bodySmall text-light-text-hint">{displaySku(selected.sku)}</p>
          </div>
          <PriceHistoryView productId={selected.id} />
        </section>
      ) : null}
    </div>
  );
}
