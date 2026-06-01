import { describe, expect, it } from 'vitest';
import { parseReceivingRows } from './parseReceivingRows';

const HEADER = ['sku', 'name', 'category', 'unit', 'cost', 'price', 'quantity', 'reorder_level'];
const grid = (...rows: string[][]) => [HEADER, ...rows];

describe('parseReceivingRows', () => {
  it('parses a full row and applies defaults', () => {
    const { rows, headerError } = parseReceivingRows(
      grid(['SP-1', 'Spark Plug', 'Engine', '', '60', '100', '5', '2']),
    );
    expect(headerError).toBeNull();
    expect(rows[0]).toMatchObject({
      rowNumber: 2,
      sku: 'SP-1',
      name: 'Spark Plug',
      category: 'Engine',
      unit: 'pcs', // blank default
      cost: 60,
      price: 100,
      quantity: 5,
      reorderLevel: 2,
      autoGenerateSku: false,
      errors: [],
    });
  });

  it('rejects a file whose first header is not sku', () => {
    const r = parseReceivingRows([['name', 'sku'], ['x', 'y']]);
    expect(r.rows).toEqual([]);
    expect(r.headerError).toMatch(/sku/i);
  });

  it('flags GENERATE rows', () => {
    const { rows } = parseReceivingRows(grid(['generate', 'New', '', '', '10', '20', '3', '']));
    expect(rows[0].autoGenerateSku).toBe(true);
  });

  it('errors on missing name, bad cost/price, or non-positive quantity', () => {
    const { rows } = parseReceivingRows(
      grid(
        ['A', '', '', '', '1', '2', '3', ''], // missing name
        ['B', 'b', '', '', 'x', '2', '3', ''], // bad cost
        ['C', 'c', '', '', '1', '2', '0', ''], // qty not > 0
      ),
    );
    expect(rows[0].errors[0]).toMatch(/name/i);
    expect(rows[1].errors[0]).toMatch(/cost/i);
    expect(rows[2].errors[0]).toMatch(/quantity/i);
  });

  it('skips wholly blank lines and strips commas in numbers', () => {
    const { rows } = parseReceivingRows(
      grid(['A', 'a', '', '', '1,250', '2,000', '4', ''], ['', '', '', '', '', '', '', '']),
    );
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ cost: 1250, price: 2000, quantity: 4 });
  });
});
