// Top-level route table. Until each feature lands, routes render
// <PagePlaceholder> so the shell is fully navigable from day one.

import { createBrowserRouter, Navigate, useParams } from 'react-router-dom';
import { AdminShell } from '@/presentation/layouts/AdminShell';
import { AuthLayout } from '@/presentation/layouts/AuthLayout';
import { ProtectedRoute } from './ProtectedRoute';
import { RoutePaths } from './routePaths';
import { LoginPage } from '@/presentation/features/auth/LoginPage';
import { ForgotPasswordPage } from '@/presentation/features/auth/ForgotPasswordPage';
import { AccessDeniedPage } from '@/presentation/features/access-denied/AccessDeniedPage';
import { DashboardPage } from '@/presentation/features/dashboard/DashboardPage';
import { SettingsPage } from '@/presentation/features/settings/SettingsPage';
import { AboutPage } from '@/presentation/features/settings/AboutPage';
import { CostCodeSettingsPage } from '@/presentation/features/settings/CostCodeSettingsPage';
import { TimezoneSettingsPage } from '@/presentation/features/settings/TimezoneSettingsPage';
import { UsersListPage } from '@/presentation/features/users/UsersListPage';
import { UserFormPage } from '@/presentation/features/users/UserFormPage';
import { ActivityLogsPage } from '@/presentation/features/logs/ActivityLogsPage';
import { ReportsHubPage } from '@/presentation/features/reports/ReportsHubPage';
import { SalesReportPage } from '@/presentation/features/reports/SalesReportPage';
import { ProfitReportPage } from '@/presentation/features/reports/ProfitReportPage';
import { LaborReportPage } from '@/presentation/features/reports/LaborReportPage';
import { PriceChangeReportPage } from '@/presentation/features/reports/PriceChangeReportPage';
import { SaleDetailPage } from '@/presentation/features/reports/SaleDetailPage';
import { DaySalesPage } from '@/presentation/features/sales/DaySalesPage';
import { BulkReceivingPage } from '@/presentation/features/receiving/BulkReceivingPage';
import { ReceivingDashboardPage } from '@/presentation/features/receiving/ReceivingDashboardPage';
import { ReceivingHistoryPage } from '@/presentation/features/receiving/ReceivingHistoryPage';
import { ReceivingDetailPage } from '@/presentation/features/receiving/ReceivingDetailPage';
import { ReceivingEntryPage } from '@/presentation/features/receiving/ReceivingEntryPage';
import { PriceHistoryPage } from '@/presentation/features/inventory/PriceHistoryPage';
import { ReorderSuggestionsPage } from '@/presentation/features/inventory/ReorderSuggestionsPage';
import { InventoryListPage } from '@/presentation/features/inventory/InventoryListPage';
import { ProductDrawer } from '@/presentation/features/inventory/ProductDrawer';
import { ProductEditDrawer } from '@/presentation/features/inventory/ProductEditDrawer';
import { InventoryFormPage } from '@/presentation/features/inventory/InventoryFormPage';
import { ManageListsPage } from '@/presentation/features/settings/ManageListsPage';
import { MechanicsPage } from '@/presentation/features/settings/MechanicsPage';
import { SuppliersListPage } from '@/presentation/features/suppliers/SuppliersListPage';
import { SupplierFormPage } from '@/presentation/features/suppliers/SupplierFormPage';
import { PosPage } from '@/presentation/features/pos/PosPage';
import { CheckoutPage } from '@/presentation/features/pos/CheckoutPage';
import { JobOrdersPage } from '@/presentation/features/jobOrders/JobOrdersPage';
import { VoidRequestsPage } from '@/presentation/features/voidRequests/VoidRequestsPage';
import { JobOrderEditPage } from '@/presentation/features/jobOrders/JobOrderEditPage';
import { EmployeesPage } from '@/presentation/features/hr/EmployeesPage';
import { PayrollPage } from '@/presentation/features/hr/PayrollPage';
import { PayslipsPage } from '@/presentation/features/hr/PayslipsPage';
import { PayslipDetailPage } from '@/presentation/features/hr/PayslipDetailPage';
import { HrSettingsPage } from '@/presentation/features/hr/HrSettingsPage';
import { ExpensesPage } from '@/presentation/features/expenses/ExpensesPage';
import { ExpenseFormPage } from '@/presentation/features/expenses/ExpenseFormPage';

// HR moved back to top-level /hr/* (its own Admin sidebar group) — these keep
// the interim /settings/hr/* bookmarks/links alive.
function HrPayslipDetailRedirect() {
  const { id = '' } = useParams();
  return <Navigate to={`${RoutePaths.hrPayslips}/${id}`} replace />;
}

// Drafts renamed to Job Orders — these keep old bookmarks/links alive.
function ProductEditRedirect() {
  const { id = '' } = useParams();
  return <Navigate to={`/inventory/${id}/edit`} replace />;
}

function JobOrderDetailRedirect() {
  const { id = '' } = useParams();
  return <Navigate to={`${RoutePaths.jobOrders}/${id}`} replace />;
}

export const router = createBrowserRouter(
  [
    {
      element: <AuthLayout />,
      children: [
        { path: RoutePaths.login, element: <LoginPage /> },
        { path: RoutePaths.forgotPassword, element: <ForgotPasswordPage /> },
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
        { path: RoutePaths.checkout, element: <CheckoutPage /> },
        { path: RoutePaths.jobOrders, element: <JobOrdersPage /> },
        { path: RoutePaths.jobOrderEdit, element: <JobOrderEditPage /> },
        { path: RoutePaths.voidRequests, element: <VoidRequestsPage /> },
        // The product view is a drawer rendered OVER the list, so it is a
        // child route: the list stays mounted and keeps its scroll, filters
        // and page. Static siblings like /inventory/add outrank ':id'.
        {
          path: RoutePaths.inventory,
          element: <InventoryListPage />,
          children: [
            { path: ':id', element: <ProductDrawer /> },
            { path: ':id/edit', element: <ProductEditDrawer /> },
          ],
        },
        { path: RoutePaths.productAdd, element: <InventoryFormPage /> },
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
        { path: RoutePaths.expenses, element: <ExpensesPage /> },
        { path: RoutePaths.expenseAdd, element: <ExpenseFormPage /> },
        { path: RoutePaths.expenseEdit, element: <ExpenseFormPage /> },
        { path: RoutePaths.reports, element: <ReportsHubPage /> },
        { path: RoutePaths.salesReport, element: <SalesReportPage /> },
        { path: RoutePaths.daySales, element: <DaySalesPage /> },
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
        { path: RoutePaths.timezoneSettings, element: <TimezoneSettingsPage /> },
        { path: RoutePaths.manageLists, element: <ManageListsPage /> },
        { path: RoutePaths.mechanics, element: <MechanicsPage /> },
        { path: RoutePaths.about, element: <AboutPage /> },
        { path: RoutePaths.hrEmployees, element: <EmployeesPage /> },
        { path: RoutePaths.hrPayroll, element: <PayrollPage /> },
        { path: RoutePaths.hrPayslips, element: <PayslipsPage /> },
        { path: RoutePaths.hrPayslipDetail, element: <PayslipDetailPage /> },
        { path: RoutePaths.hrSettings, element: <HrSettingsPage /> },
      ],
    },
    // Bare /hr (the sidebar group's header link) lands on Employees.
    { path: RoutePaths.hr, element: <Navigate to={RoutePaths.hrEmployees} replace /> },
    // Old /settings/hr/* bookmarks — redirect to the top-level /hr/* homes.
    { path: '/settings/hr/employees', element: <Navigate to={RoutePaths.hrEmployees} replace /> },
    { path: '/settings/hr/payroll', element: <Navigate to={RoutePaths.hrPayroll} replace /> },
    { path: '/settings/hr/payslips', element: <Navigate to={RoutePaths.hrPayslips} replace /> },
    { path: '/settings/hr/payslips/:id', element: <HrPayslipDetailRedirect /> },
    { path: '/settings/hr/config', element: <Navigate to={RoutePaths.hrSettings} replace /> },
    // Old edit bookmarks — product editing moved into the drawer.
    { path: '/inventory/edit/:id', element: <ProductEditRedirect /> },
    // Old /drafts bookmarks — Drafts renamed to Job Orders.
    { path: '/drafts', element: <Navigate to={RoutePaths.jobOrders} replace /> },
    { path: '/drafts/:id', element: <JobOrderDetailRedirect /> },
    { path: '*', element: <Navigate to={RoutePaths.dashboard} replace /> },
  ],
  { basename: '/' },
);
