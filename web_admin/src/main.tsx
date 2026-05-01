import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClientProvider } from '@tanstack/react-query';
import { App } from './App';
import { DiProvider } from '@/infrastructure/di/container';
import { queryClient } from '@/infrastructure/query/queryClient';
import './index.css';

const root = document.getElementById('root');
if (!root) throw new Error('Missing #root element');

createRoot(root).render(
  <StrictMode>
    <DiProvider>
      <QueryClientProvider client={queryClient}>
        <App />
      </QueryClientProvider>
    </DiProvider>
  </StrictMode>,
);
