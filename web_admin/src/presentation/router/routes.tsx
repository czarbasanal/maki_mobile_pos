// Top-level route table. Until each feature lands, routes render
// <PagePlaceholder> so the shell is fully navigable from day one.

import { createBrowserRouter, Navigate } from 'react-router-dom';
import { AdminShell } from '@/presentation/layouts/AdminShell';
import { AuthLayout } from '@/presentation/layouts/AuthLayout';
import { ProtectedRoute } from './ProtectedRoute';
import { RoutePaths } from './routePaths';
import { LoginPage } from '@/presentation/features/auth/LoginPage';
import { AccessDeniedPage } from '@/presentation/features/access-denied/AccessDeniedPage';
import { DashboardPage } from '@/presentation/features/dashboard/DashboardPage';
import { PagePlaceholder } from '@/presentation/components/common/PagePlaceholder';

const placeholder = (title: string, phase: string) => (
  <PagePlaceholder title={title} phase={phase} />
);

export const router = createBrowserRouter(
  [
    {
      element: <AuthLayout />,
      children: [
        { path: RoutePaths.login, element: <LoginPage /> },
        { path: RoutePaths.accessDenied, element: <AccessDeniedPage /> },
      ],
    },
    {
      element: (
        <ProtectedRoute>
          <AdminShell />
        </ProtectedRoute>
      ),
      children: [
        { path: RoutePaths.dashboard, element: <DashboardPage /> },
        { path: RoutePaths.pos, element: placeholder('POS', 'phase 11') },
        { path: RoutePaths.checkout, element: placeholder('Checkout', 'phase 11') },
        { path: RoutePaths.drafts, element: placeholder('Drafts', 'phase 10') },
        { path: RoutePaths.draftEdit, element: placeholder('Edit Draft', 'phase 10') },
        { path: RoutePaths.inventory, element: placeholder('Inventory', 'phase 7') },
        { path: RoutePaths.productAdd, element: placeholder('New product', 'phase 7') },
        { path: RoutePaths.productEdit, element: placeholder('Edit product', 'phase 7') },
        { path: RoutePaths.receiving, element: placeholder('Receiving', 'phase 8') },
        { path: RoutePaths.bulkReceiving, element: placeholder('Bulk receiving', 'phase 8') },
        { path: RoutePaths.bulkReceivingDetail, element: placeholder('Bulk receiving', 'phase 8') },
        { path: RoutePaths.suppliers, element: placeholder('Suppliers', 'phase 6') },
        { path: RoutePaths.supplierAdd, element: placeholder('New supplier', 'phase 6') },
        { path: RoutePaths.supplierEdit, element: placeholder('Edit supplier', 'phase 6') },
        { path: RoutePaths.expenses, element: placeholder('Expenses', 'phase 9') },
        { path: RoutePaths.expenseAdd, element: placeholder('New expense', 'phase 9') },
        { path: RoutePaths.expenseEdit, element: placeholder('Edit expense', 'phase 9') },
        { path: RoutePaths.pettyCash, element: placeholder('Petty cash', 'phase 9') },
        { path: RoutePaths.pettyCashNew, element: placeholder('Petty cash entry', 'phase 9') },
        { path: RoutePaths.reports, element: placeholder('Reports', 'phase 12') },
        { path: RoutePaths.salesReport, element: placeholder('Sales report', 'phase 12') },
        { path: RoutePaths.profitReport, element: placeholder('Profit report', 'phase 12') },
        { path: RoutePaths.saleDetail, element: placeholder('Sale detail', 'phase 12') },
        { path: RoutePaths.users, element: placeholder('Users', 'phase 4') },
        { path: RoutePaths.userAdd, element: placeholder('New user', 'phase 4') },
        { path: RoutePaths.userEdit, element: placeholder('Edit user', 'phase 4') },
        { path: RoutePaths.userLogs, element: placeholder('Activity logs', 'phase 5') },
        { path: RoutePaths.settings, element: placeholder('Settings', 'phase 3') },
        { path: RoutePaths.costCodeSettings, element: placeholder('Cost codes', 'phase 3') },
        { path: RoutePaths.about, element: placeholder('About', 'phase 3') },
      ],
    },
    { path: '*', element: <Navigate to={RoutePaths.dashboard} replace /> },
  ],
  { basename: '/admin' },
);
