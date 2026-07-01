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
import { SettingsPage } from '@/presentation/features/settings/SettingsPage';
import { AboutPage } from '@/presentation/features/settings/AboutPage';
import { CostCodeSettingsPage } from '@/presentation/features/settings/CostCodeSettingsPage';
import { UsersListPage } from '@/presentation/features/users/UsersListPage';
import { UserFormPage } from '@/presentation/features/users/UserFormPage';
import { ActivityLogsPage } from '@/presentation/features/logs/ActivityLogsPage';
import { ReportsHubPage } from '@/presentation/features/reports/ReportsHubPage';
import { SalesReportPage } from '@/presentation/features/reports/SalesReportPage';
import { ProfitReportPage } from '@/presentation/features/reports/ProfitReportPage';
import { LaborReportPage } from '@/presentation/features/reports/LaborReportPage';
import { PriceChangeReportPage } from '@/presentation/features/reports/PriceChangeReportPage';
import { SaleDetailPage } from '@/presentation/features/reports/SaleDetailPage';
import { BulkReceivingPage } from '@/presentation/features/receiving/BulkReceivingPage';
import { ReceivingDashboardPage } from '@/presentation/features/receiving/ReceivingDashboardPage';
import { ReceivingHistoryPage } from '@/presentation/features/receiving/ReceivingHistoryPage';
import { ReceivingDetailPage } from '@/presentation/features/receiving/ReceivingDetailPage';
import { ReceivingEntryPage } from '@/presentation/features/receiving/ReceivingEntryPage';
import { PriceHistoryPage } from '@/presentation/features/inventory/PriceHistoryPage';
import { ReorderSuggestionsPage } from '@/presentation/features/inventory/ReorderSuggestionsPage';
import { InventoryListPage } from '@/presentation/features/inventory/InventoryListPage';
import { InventoryDetailPage } from '@/presentation/features/inventory/InventoryDetailPage';
import { InventoryFormPage } from '@/presentation/features/inventory/InventoryFormPage';
import { ManageListsPage } from '@/presentation/features/settings/ManageListsPage';
import { MechanicsPage } from '@/presentation/features/settings/MechanicsPage';
import { SuppliersListPage } from '@/presentation/features/suppliers/SuppliersListPage';
import { SupplierFormPage } from '@/presentation/features/suppliers/SupplierFormPage';
import { PosPage } from '@/presentation/features/pos/PosPage';
import { DraftsPage } from '@/presentation/features/drafts/DraftsPage';
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
        { path: RoutePaths.pos, element: <PosPage /> },
        { path: RoutePaths.checkout, element: placeholder('Checkout', 'phase 11') },
        { path: RoutePaths.drafts, element: <DraftsPage /> },
        { path: RoutePaths.draftEdit, element: placeholder('Edit Draft', 'phase 10') },
        { path: RoutePaths.inventory, element: <InventoryListPage /> },
        { path: RoutePaths.productAdd, element: <InventoryFormPage /> },
        { path: RoutePaths.productEdit, element: <InventoryFormPage /> },
        { path: RoutePaths.productDetail, element: <InventoryDetailPage /> },
        { path: RoutePaths.priceHistory, element: <PriceHistoryPage /> },
        { path: RoutePaths.reorder, element: <ReorderSuggestionsPage /> },
        { path: RoutePaths.receiving, element: <ReceivingDashboardPage /> },
        { path: RoutePaths.receivingNew, element: <ReceivingEntryPage /> },
        { path: RoutePaths.receivingNewDraft, element: <ReceivingEntryPage /> },
        { path: RoutePaths.receivingHistory, element: <ReceivingHistoryPage /> },
        { path: RoutePaths.bulkReceiving, element: <BulkReceivingPage /> },
        { path: RoutePaths.receivingDetail, element: <ReceivingDetailPage /> },
        { path: RoutePaths.suppliers, element: <SuppliersListPage /> },
        { path: RoutePaths.supplierAdd, element: <SupplierFormPage /> },
        { path: RoutePaths.supplierEdit, element: <SupplierFormPage /> },
        { path: RoutePaths.expenses, element: placeholder('Expenses', 'phase 9') },
        { path: RoutePaths.expenseAdd, element: placeholder('New expense', 'phase 9') },
        { path: RoutePaths.expenseEdit, element: placeholder('Edit expense', 'phase 9') },
        { path: RoutePaths.pettyCash, element: placeholder('Petty cash', 'phase 9') },
        { path: RoutePaths.pettyCashNew, element: placeholder('Petty cash entry', 'phase 9') },
        { path: RoutePaths.reports, element: <ReportsHubPage /> },
        { path: RoutePaths.salesReport, element: <SalesReportPage /> },
        { path: RoutePaths.profitReport, element: <ProfitReportPage /> },
        { path: RoutePaths.laborReport, element: <LaborReportPage /> },
        { path: RoutePaths.priceChangeReport, element: <PriceChangeReportPage /> },
        { path: RoutePaths.saleDetail, element: <SaleDetailPage /> },
        { path: RoutePaths.users, element: <UsersListPage /> },
        { path: RoutePaths.userAdd, element: <UserFormPage /> },
        { path: RoutePaths.userEdit, element: <UserFormPage /> },
        { path: RoutePaths.userLogs, element: <ActivityLogsPage /> },
        { path: RoutePaths.settings, element: <SettingsPage /> },
        { path: RoutePaths.costCodeSettings, element: <CostCodeSettingsPage /> },
        { path: RoutePaths.manageLists, element: <ManageListsPage /> },
        { path: RoutePaths.mechanics, element: <MechanicsPage /> },
        { path: RoutePaths.about, element: <AboutPage /> },
      ],
    },
    { path: '*', element: <Navigate to={RoutePaths.dashboard} replace /> },
  ],
  { basename: '/' },
);
