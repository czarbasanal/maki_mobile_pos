// Separate from vite.config.ts because vitest 2.x bundles its own vite which
// conflicts with the project's vite 6 types. Split lets each tool use its own
// types cleanly. The react plugin is intentionally omitted here — vitest
// handles JSX through its bundled esbuild transform for tests.

import { defineConfig } from 'vitest/config';
import path from 'node:path';

export default defineConfig({
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./src/test/setup.ts'],
  },
});
