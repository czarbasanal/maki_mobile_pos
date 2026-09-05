// Top-level route table. Until each feature lands, routes render
// <PagePlaceholder> so the shell is fully navigable from day one.

import { createBrowserRouter, Navigate, useParams } from 'react-router-dom';
import { AppShell } from '@/presentation/layouts/AppShell';
import type { PageChrome } from '@/presentation/layouts/HeaderBar';
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
import { UserModal } from '@/presentation/features/users/UserModal';
import { ActivityLogsPage } from '@/presentation/features/logs/ActivityLogsPage';
import { ReportsHubPage } from '@/presentation/features/reports/ReportsHubPage';
import { SalesReportPage } from '@/presentation/features/reports/SalesReportPage';
import { ProfitReportPage } from '@/presentation/features/reports/ProfitReportPage';
import { LaborReportPage } from '@/presentation/features/reports/LaborReportPage';
import { PriceChangeReportPage } from '@/presentation/features/reports/PriceChangeReportPage';
import { SaleDetailPage } from '@/presentation/features/reports/SaleDetailPage';
import { BulkReceivingPage } from '@/presentation/features/receiving/BulkReceivingPage';
import { ReceivingListPage } from '@/presentation/features/receiving/ReceivingListPage';
import { ReceivingDetailPage } from '@/presentation/features/receiving/ReceivingDetailPage';
import { ReceivingEntryPage } from '@/presentation/features/receiving/ReceivingEntryPage';
import { PriceHistoryPage } from '@/presentation/features/inventory/PriceHistoryPage';
import { InventoryListPage } from '@/presentation/features/inventory/InventoryListPage';
import { ProductModal } from '@/presentation/features/inventory/ProductModal';
import { ManageListsPage } from '@/presentation/features/settings/ManageListsPage';
import { MechanicsPage } from '@/presentation/features/settings/MechanicsPage';
import { ProductTagsPage } from '@/presentation/features/settings/ProductTagsPage';
import { AdjustmentReasonsPage } from '@/presentation/features/settings/AdjustmentReasonsPage';
import { SuppliersListPage } from '@/presentation/features/suppliers/SuppliersListPage';
import { SupplierModal } from '@/presentation/features/suppliers/SupplierModal';
import { PosPage } from '@/presentation/features/pos/PosPage';
import { CheckoutPage } from '@/presentation/features/pos/CheckoutPage';
import { JobOrdersPage } from '@/presentation/features/jobOrders/JobOrdersPage';
import { VoidRequestsPage } from '@/presentation/features/voidRequests/VoidRequestsPage';
import { PurchaseOrdersPage } from '@/presentation/features/purchaseOrders/PurchaseOrdersPage';
import { PurchaseOrderBuilderPage } from '@/presentation/features/purchaseOrders/PurchaseOrderBuilderPage';
import { PurchaseOrderDetailPage } from '@/presentation/features/purchaseOrders/PurchaseOrderDetailPage';
import { JobOrderEditPage } from '@/presentation/features/jobOrders/JobOrderEditPage';
import { EmployeesPage } from '@/presentation/features/hr/EmployeesPage';
import { PayrollPage } from '@/presentation/features/hr/PayrollPage';
import { PayslipsPage } from '@/presentation/features/hr/PayslipsPage';
import { PayslipDetailPage } from '@/presentation/features/hr/PayslipDetailPage';
import { HrSettingsPage } from '@/presentation/features/hr/HrSettingsPage';
import { ExpensesPage } from '@/presentation/features/expenses/ExpensesPage';
import { ExpenseModal } from '@/presentation/features/expenses/ExpenseModal';

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

/** /inventory/:id was the product drawer; it now opens the edit modal. */
function ProductViewRedirect() {
  const { id } = useParams<{ id: string }>();
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
          <AppShell />
        </ProtectedRoute>
      ),
      children: [
        {
          path: RoutePaths.dashboard,
          element: <DashboardPage />,
          handle: {
            title: 'Dashboard',
            subtitle: 'Store performance at a glance',
            primaryAction: { label: 'New sale', to: RoutePaths.pos },
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.pos,
          element: <PosPage />,
          handle: { title: 'POS' } satisfies PageChrome,
        },
        {
          path: RoutePaths.checkout,
          element: <CheckoutPage />,
          handle: { title: 'Checkout' } satisfies PageChrome,
        },
        {
          path: RoutePaths.jobOrders,
          element: <JobOrdersPage />,
          handle: {
            title: 'Job Orders',
            subtitle:
              'Service tickets — resume an open one into the POS, or open a billed one to view its sale.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.jobOrderEdit,
          element: <JobOrderEditPage />,
          handle: { title: 'Edit Job Order' } satisfies PageChrome,
        },
        {
          path: RoutePaths.voidRequests,
          element: <VoidRequestsPage />,
          handle: {
            title: 'Void Requests',
            subtitle:
              'Approving voids the sale and puts its stock back. Rejecting leaves the sale as it stands and tells the cashier why.',
          } satisfies PageChrome,
        },
        // The product view is a drawer rendered OVER the list, so it is a
        // child route: the list stays mounted and keeps its scroll, filters
        // and page. Static siblings like /inventory/add outrank ':id'. The
        // drawer children have no handle of their own — usePageChrome
        // resolves the deepest handle, so the list's shows through.
        {
          path: RoutePaths.inventory,
          element: <InventoryListPage />,
          handle: {
            title: 'Inventory',
            subtitle: 'Products, stock levels, and pricing.',
          } satisfies PageChrome,
          children: [
            // Static 'add' outranks the dynamic ':id' in route matching, so
            // the modal wins over the drawer for /inventory/add.
            { path: 'add', element: <ProductModal /> },
            // The read-only product drawer is retired — a row opens the edit
            // modal directly. Old /inventory/:id links land there too.
            { path: ':id', element: <ProductViewRedirect /> },
            { path: ':id/edit', element: <ProductModal /> },
          ],
        },
        {
          path: RoutePaths.priceHistory,
          element: <PriceHistoryPage />,
          handle: {
            title: 'Price History',
            subtitle: "Search a product to see its cost & selling-price changes over time.",
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.purchaseOrders,
          element: <PurchaseOrdersPage />,
          handle: {
            title: 'Purchase Orders',
            subtitle:
              'One list per buying trip. Where each part is bought is recorded on the line, as you go.',
          } satisfies PageChrome,
        },
        // Static sibling outranks ':id'.
        {
          path: RoutePaths.purchaseOrderNew,
          element: <PurchaseOrderBuilderPage />,
          handle: { title: 'New purchase order' } satisfies PageChrome,
        },
        {
          path: RoutePaths.purchaseOrderDetail,
          element: <PurchaseOrderDetailPage />,
          handle: { title: 'Purchase order' } satisfies PageChrome,
        },
        {
          path: RoutePaths.receiving,
          element: <ReceivingListPage />,
          handle: {
            title: 'Receiving',
            subtitle: "Record incoming stock from suppliers, and track what you've received.",
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.receivingNew,
          element: <ReceivingEntryPage />,
          handle: { title: 'New receiving' } satisfies PageChrome,
        },
        {
          path: RoutePaths.receivingNewDraft,
          element: <ReceivingEntryPage />,
          handle: { title: 'Resume receiving' } satisfies PageChrome,
        },
        {
          // History folded into the redesigned list (search, filters, date
          // range, pagination live there now); old links land on it.
          path: RoutePaths.receivingHistory,
          element: <Navigate to={RoutePaths.receiving} replace />,
          handle: {
            title: 'Receiving',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.bulkReceiving,
          element: <BulkReceivingPage />,
          handle: {
            title: 'Bulk receiving',
            subtitle:
              'Upload a CSV (sku, name, category, unit, cost, price, quantity, reorder_level). Existing SKUs get stock added; a different cost spawns a variation; new SKUs (or "GENERATE") are created.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.receivingDetail,
          element: <ReceivingDetailPage />,
          handle: { title: 'Receiving detail' } satisfies PageChrome,
        },
        {
          path: RoutePaths.suppliers,
          element: <SuppliersListPage />,
          handle: {
            title: 'Suppliers',
            subtitle: 'Vendor directory used by inventory and receiving.',
          } satisfies PageChrome,
          children: [
            // Add/edit render as modals over the directory via its Outlet.
            { path: 'add', element: <SupplierModal /> },
            { path: 'edit/:id', element: <SupplierModal /> },
          ],
        },
        {
          // Add/edit render as modals over the list via its Outlet — exactly
          // like ProductModal/SupplierModal (product-modal guide).
          path: RoutePaths.expenses,
          element: <ExpensesPage />,
          handle: { title: 'Expenses', subtitle: 'Shop expenses and receipts.' } satisfies PageChrome,
          children: [
            { path: 'add', element: <ExpenseModal /> },
            { path: 'edit/:id', element: <ExpenseModal /> },
          ],
        },
        {
          path: RoutePaths.reports,
          element: <ReportsHubPage />,
          handle: {
            title: 'Reports',
            subtitle: 'Sales and profit over any date range.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.salesReport,
          element: <SalesReportPage />,
          handle: {
            title: 'Sales report',
            subtitle: 'Sales and payment breakdown for the selected range.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.profitReport,
          element: <ProfitReportPage />,
          handle: {
            title: 'Profit report',
            subtitle: 'Cost of goods, gross profit, and margin for the selected range.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.laborReport,
          element: <LaborReportPage />,
          handle: {
            title: 'Labor report',
            subtitle: 'Service revenue and per-mechanic breakdown for the selected range.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.priceChangeReport,
          element: <PriceChangeReportPage />,
          handle: {
            title: 'Price changes',
            subtitle: 'Price/cost changes across products for the selected range.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.saleDetail,
          element: <SaleDetailPage />,
          handle: { title: 'Sale detail' } satisfies PageChrome,
        },
        // The add/manage modal renders OVER the list (child routes, like
        // Inventory): the list stays mounted with its filters and page.
        {
          path: RoutePaths.users,
          element: <UsersListPage />,
          handle: {
            title: 'Users',
            subtitle: 'Add, edit, and manage admin users and staff accounts.',
          } satisfies PageChrome,
          children: [
            { path: 'add', element: <UserModal /> },
            { path: 'edit/:id', element: <UserModal /> },
          ],
        },
        {
          path: RoutePaths.userLogs,
          element: <ActivityLogsPage />,
          handle: {
            title: 'Activity logs',
            subtitle: 'Audit trail of user actions across both web and mobile clients.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.settings,
          element: <SettingsPage />,
          handle: {
            title: 'Settings',
            subtitle: 'Account, administration, and app information.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.costCodeSettings,
          element: <CostCodeSettingsPage />,
          handle: {
            title: 'Cost codes',
            subtitle: "Encode product costs as letters so they're hidden from non-admins.",
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.timezoneSettings,
          element: <TimezoneSettingsPage />,
          handle: {
            title: 'Time & timezone',
            subtitle:
              'The clock the shop runs on — business day rollover, sale numbers and report dates all follow it.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.manageLists,
          element: <ManageListsPage />,
          handle: {
            title: 'Manage Lists',
            subtitle: 'Admin-managed dropdown values used across the app.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.mechanics,
          element: <MechanicsPage />,
          handle: {
            title: 'Mechanics',
            subtitle: 'Mechanics available for the labor picker on service sales.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.productTags,
          element: <ProductTagsPage />,
          handle: {
            title: 'Product tags',
            subtitle: 'Color-coded markers shown on inventory rows.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.adjustmentReasons,
          element: <AdjustmentReasonsPage />,
          handle: {
            title: 'Adjustment reasons',
            subtitle: 'Why stock was corrected — shown in the adjust-stock dialog.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.about,
          element: <AboutPage />,
          handle: { title: 'About', subtitle: 'Version and technical information.' } satisfies PageChrome,
        },
        {
          path: RoutePaths.hrEmployees,
          element: <EmployeesPage />,
          handle: {
            title: 'Employees',
            subtitle: 'Employees registered for payroll.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.hrPayroll,
          element: <PayrollPage />,
          handle: {
            title: 'Payroll',
            subtitle: "Generate a payslip for one employee's pay period.",
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.hrPayslips,
          element: <PayslipsPage />,
          handle: {
            title: 'Payslips',
            subtitle: 'Generated payslips, most recent pay period first.',
          } satisfies PageChrome,
        },
        {
          path: RoutePaths.hrPayslipDetail,
          element: <PayslipDetailPage />,
          handle: { title: 'Payslip' } satisfies PageChrome,
        },
        {
          path: RoutePaths.hrSettings,
          element: <HrSettingsPage />,
          handle: {
            title: 'HR Settings',
            subtitle: 'Week start day and holiday pay percentages used when computing payslips.',
          } satisfies PageChrome,
        },
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
    // Reorder moved inside the buying list. Without this the old path would
    // fall through to /inventory/:id and open a product drawer for a product
    // called "reorder".
    {
      path: '/inventory/reorder',
      element: <Navigate to={RoutePaths.purchaseOrderNew} replace />,
    },
    // Price History moved out from under /inventory; keep old links working.
    {
      path: '/inventory/price-history',
      element: <Navigate to={RoutePaths.priceHistory} replace />,
    },
    { path: '/drafts/:id', element: <JobOrderDetailRedirect /> },
    { path: '*', element: <Navigate to={RoutePaths.dashboard} replace /> },
  ],
  { basename: '/' },
);
