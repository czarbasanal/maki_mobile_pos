// Centralized TanStack Query keys. One per resource, factory-style so we can
// derive scoped variants (e.g. by id, by filter) without typos in strings.

export const queryKeys = {
  auth: {
    currentUser: ['auth', 'currentUser'] as const,
  },
  users: {
    all: ['users'] as const,
    byId: (id: string) => ['users', id] as const,
  },
  products: {
    all: ['products'] as const,
    byId: (id: string) => ['products', id] as const,
    bySupplier: (supplierId: string) => ['products', 'bySupplier', supplierId] as const,
    lowStock: ['products', 'lowStock'] as const,
  },
  suppliers: {
    all: ['suppliers'] as const,
    byId: (id: string) => ['suppliers', id] as const,
  },
  sales: {
    all: ['sales'] as const,
    byId: (id: string) => ['sales', id] as const,
    recent: (limit: number) => ['sales', 'recent', limit] as const,
  },
  drafts: {
    all: ['drafts'] as const,
    byId: (id: string) => ['drafts', id] as const,
  },
  expenses: {
    all: ['expenses'] as const,
    byId: (id: string) => ['expenses', id] as const,
  },
  receivings: {
    all: ['receivings'] as const,
    byId: (id: string) => ['receivings', id] as const,
  },
  pettyCash: {
    all: ['pettyCash'] as const,
    balance: ['pettyCash', 'balance'] as const,
  },
  logs: {
    all: ['logs'] as const,
  },
  costCode: {
    current: ['costCode', 'current'] as const,
  },
} as const;
