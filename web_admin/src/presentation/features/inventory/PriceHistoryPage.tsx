import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useProducts } from '@/presentation/hooks/useProducts';
import type { Product } from '@/domain/entities';
import { PriceHistoryView } from './PriceHistoryView';

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

  const q = queryText.trim().toLowerCase();
  const matches =
    q.length === 0
      ? []
      : (products ?? [])
          .filter((p) => p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q))
          .slice(0, 10);

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          Price History
        </h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Search a product to see its cost &amp; selling-price changes over time.
        </p>
      </header>

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
          <ul className="mt-tk-xs overflow-hidden rounded-md border border-light-hairline bg-light-card">
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
                  <span className="text-light-text-hint">{p.sku}</span>
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
          <div>
            <h2 className="text-bodyMedium font-semibold text-light-text">{selected.name}</h2>
            <p className="text-bodySmall text-light-text-hint">{selected.sku}</p>
          </div>
          <PriceHistoryView productId={selected.id} />
        </section>
      ) : null}
    </div>
  );
}
