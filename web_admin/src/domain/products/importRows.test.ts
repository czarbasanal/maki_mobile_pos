import { describe, expect, it } from 'vitest';
import { defaultCostCode } from '../entities';
import { parseImportRows } from './importRows';

// Default cipher: 1→N 2→B 5→F, so "NBF" decodes to 125.
const cipher = defaultCostCode;
const HEADER = ['name', 'category', 'code', 'price', 'qty', 'unit', 'reorder_level', 'supplier'];

function grid(...dataRows: string[][]) {
  return [HEADER, ...dataRows];
}

describe('parseImportRows', () => {
  it('decodes cost, parses numbers (commas stripped), applies defaults', () => {
    const { rows, headerError } = parseImportRows(
      grid(['Spark Plug', 'Engine', 'NBF', '1,250', '4', '', '2', 'Acme']),
      cipher,
    );
    expect(headerError).toBeNull();
    expect(rows[0]).toMatchObject({
      rowNumber: 1,
      name: 'Spark Plug',
      category: 'Engine',
      code: 'NBF',
      cost: 125,
      price: 1250,
      quantity: 4,
      reorderLevel: 2,
      unit: 'pcs', // blank -> default
      supplierName: 'Acme',
      errors: [],
    });
  });

  it('rejects the file when a required header is missing', () => {
    const r = parseImportRows([['name', 'price'], ['X', '5']], cipher);
    expect(r.rows).toEqual([]);
    expect(r.headerError).toContain('code');
  });

  it('errors a row with a blank name, bad price, or blank/undecodable code', () => {
    const { rows } = parseImportRows(
      grid(
        ['', 'c', 'NBF', '10', '', '', '', ''], // blank name
        ['A', 'c', 'NBF', 'abc', '', '', '', ''], // bad price
        ['B', 'c', '', '10', '', '', '', ''], // blank code
        ['C', 'c', 'NX', '10', '', '', '', ''], // undecodable code (X unknown)
      ),
      cipher,
    );
    expect(rows[0].errors[0]).toMatch(/name/i);
    expect(rows[1].errors[0]).toMatch(/price/i);
    expect(rows[2].errors[0]).toMatch(/cost code is required/i);
    expect(rows[3].errors[0]).toMatch(/cannot be decoded/i);
  });

  it('matches headers case-insensitively with aliases and skips blank lines', () => {
    const { rows } = parseImportRows(
      [
        ['Name', 'Code', 'Price', 'Quantity', 'ReorderLevel'],
        ['Widget', 'NBF', '50', '3', '1'],
        ['', '', '', '', ''], // blank -> skipped
      ],
      cipher,
    );
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ name: 'Widget', cost: 125, quantity: 3, reorderLevel: 1 });
  });

  it('uppercases the code before decoding', () => {
    const { rows } = parseImportRows(grid(['A', '', 'nbf', '10', '', '', '', '']), cipher);
    expect(rows[0].code).toBe('NBF');
    expect(rows[0].cost).toBe(125);
  });
});
