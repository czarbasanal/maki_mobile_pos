import { RouterProvider } from 'react-router-dom';
import { router } from '@/presentation/router/routes';
import { useAuthBootstrap } from '@/presentation/hooks/useAuthBootstrap';

export function App() {
  useAuthBootstrap();
  return <RouterProvider router={router} />;
}
