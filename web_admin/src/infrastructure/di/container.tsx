// Dependency injection container. Holds repository instances so use cases /
// hooks consume contracts, not concrete Firestore code. Tests can override by
// passing a different container value to <DiProvider>.

import { createContext, useContext, useEffect, useMemo, type ReactNode } from 'react';
import { auth } from '@/infrastructure/firebase/auth';
import { db } from '@/infrastructure/firebase/firestore';
import { FirebaseAuthRepository } from '@/data/repositories/FirebaseAuthRepository';
import { FirestoreSaleRepository } from '@/data/repositories/FirestoreSaleRepository';
import { FirestoreProductRepository } from '@/data/repositories/FirestoreProductRepository';
import { FirestoreCostCodeRepository } from '@/data/repositories/FirestoreCostCodeRepository';
import { FirestoreUserRepository } from '@/data/repositories/FirestoreUserRepository';
import { FirestoreActivityLogRepository } from '@/data/repositories/FirestoreActivityLogRepository';
import { FirestoreSupplierRepository } from '@/data/repositories/FirestoreSupplierRepository';
import { FirestoreReceivingRepository } from '@/data/repositories/FirestoreReceivingRepository';
import { FirestoreCategoryRepository } from '@/data/repositories/FirestoreCategoryRepository';
import { FirestoreMechanicRepository } from '@/data/repositories/FirestoreMechanicRepository';
import { FirestoreJobOrderRepository } from '@/data/repositories/FirestoreJobOrderRepository';
import { FirestoreEmployeeRepository } from '@/data/repositories/FirestoreEmployeeRepository';
import { FirestorePayslipRepository } from '@/data/repositories/FirestorePayslipRepository';
import { FirestoreHrSettingsRepository } from '@/data/repositories/FirestoreHrSettingsRepository';
import { FirestoreExpenseRepository } from '@/data/repositories/FirestoreExpenseRepository';
import { FirestoreVoidRequestRepository } from '@/data/repositories/FirestoreVoidRequestRepository';
import { FirestoreShopTimezoneRepository } from '@/data/repositories/FirestoreShopTimezoneRepository';
import { FirestoreDrawerStateRepository } from '@/data/repositories/FirestoreDrawerStateRepository';
import { FirestoreShopFeeRepository } from '@/data/repositories/FirestoreShopFeeRepository';
import { FirestoreMotorcycleModelRepository } from '@/data/repositories/FirestoreMotorcycleModelRepository';
import type { AuthRepository } from '@/domain/repositories/AuthRepository';
import type { SaleRepository } from '@/domain/repositories/SaleRepository';
import type { ProductRepository } from '@/domain/repositories/ProductRepository';
import type { CostCodeRepository } from '@/domain/repositories/CostCodeRepository';
import type { UserRepository } from '@/domain/repositories/UserRepository';
import type { ActivityLogRepository } from '@/domain/repositories/ActivityLogRepository';
import type { SupplierRepository } from '@/domain/repositories/SupplierRepository';
import type { ReceivingRepository } from '@/domain/repositories/ReceivingRepository';
import type { CategoryRepository } from '@/domain/repositories/CategoryRepository';
import type { MechanicRepository } from '@/domain/repositories/MechanicRepository';
import type { JobOrderRepository } from '@/domain/repositories/JobOrderRepository';
import type { EmployeeRepository } from '@/domain/repositories/EmployeeRepository';
import type { PayslipRepository } from '@/domain/repositories/PayslipRepository';
import type { HrSettingsRepository } from '@/domain/repositories/HrSettingsRepository';
import type { ExpenseRepository } from '@/domain/repositories/ExpenseRepository';
import type { VoidRequestRepository } from '@/domain/repositories/VoidRequestRepository';
import type { ShopTimezoneRepository } from '@/domain/repositories/ShopTimezoneRepository';
import type { DrawerStateRepository } from '@/domain/repositories/DrawerStateRepository';
import type { ShopFeeRepository } from '@/domain/repositories/ShopFeeRepository';
import type { MotorcycleModelRepository } from '@/domain/repositories/MotorcycleModelRepository';
import { setAmbientShopTimezone } from '@/domain/time/shopTime';
import type { PurchaseOrderRepository } from '@/domain/repositories/PurchaseOrderRepository';
import { FirestorePurchaseOrderRepository } from '@/data/repositories/FirestorePurchaseOrderRepository';

export interface Container {
  authRepo: AuthRepository;
  saleRepo: SaleRepository;
  productRepo: ProductRepository;
  costCodeRepo: CostCodeRepository;
  userRepo: UserRepository;
  activityLogRepo: ActivityLogRepository;
  supplierRepo: SupplierRepository;
  receivingRepo: ReceivingRepository;
  categoryRepo: CategoryRepository;
  mechanicRepo: MechanicRepository;
  jobOrderRepo: JobOrderRepository;
  employeeRepo: EmployeeRepository;
  payslipRepo: PayslipRepository;
  hrSettingsRepo: HrSettingsRepository;
  expenseRepo: ExpenseRepository;
  voidRequestRepo: VoidRequestRepository;
  purchaseOrderRepo: PurchaseOrderRepository;
  shopTimezoneRepo: ShopTimezoneRepository;
  drawerStateRepo: DrawerStateRepository;
  shopFeeRepo: ShopFeeRepository;
  motorcycleModelRepo: MotorcycleModelRepository;
}

function buildDefaultContainer(): Container {
  return {
    authRepo: new FirebaseAuthRepository(auth, db),
    saleRepo: new FirestoreSaleRepository(db),
    productRepo: new FirestoreProductRepository(db),
    costCodeRepo: new FirestoreCostCodeRepository(db),
    userRepo: new FirestoreUserRepository(db),
    activityLogRepo: new FirestoreActivityLogRepository(db),
    supplierRepo: new FirestoreSupplierRepository(db),
    receivingRepo: new FirestoreReceivingRepository(db, new FirestoreProductRepository(db)),
    categoryRepo: new FirestoreCategoryRepository(db),
    mechanicRepo: new FirestoreMechanicRepository(db),
    jobOrderRepo: new FirestoreJobOrderRepository(db),
    employeeRepo: new FirestoreEmployeeRepository(db),
    payslipRepo: new FirestorePayslipRepository(db),
    hrSettingsRepo: new FirestoreHrSettingsRepository(db),
    expenseRepo: new FirestoreExpenseRepository(db),
    voidRequestRepo: new FirestoreVoidRequestRepository(db),
    purchaseOrderRepo: new FirestorePurchaseOrderRepository(db),
    shopTimezoneRepo: new FirestoreShopTimezoneRepository(db),
    drawerStateRepo: new FirestoreDrawerStateRepository(db),
    shopFeeRepo: new FirestoreShopFeeRepository(db),
    motorcycleModelRepo: new FirestoreMotorcycleModelRepository(db),
  };
}

const DiContext = createContext<Container | null>(null);

export function DiProvider({
  children,
  override,
}: {
  children: ReactNode;
  override?: Partial<Container>;
}) {
  const value = useMemo<Container>(
    () => ({ ...buildDefaultContainer(), ...(override ?? {}) }),
    [override],
  );

  // Keep the ambient shop timezone in sync for the whole app. Helpers like
  // counterKey and resolvePreset read it without a React context, so this has
  // to run once at the container level rather than per page.
  useEffect(() => {
    return value.shopTimezoneRepo.watch(setAmbientShopTimezone);
  }, [value]);

  return <DiContext.Provider value={value}>{children}</DiContext.Provider>;
}

export function useContainer(): Container {
  const c = useContext(DiContext);
  if (!c) throw new Error('useContainer must be used inside <DiProvider>');
  return c;
}

export function useAuthRepo(): AuthRepository {
  return useContainer().authRepo;
}

export function useSaleRepo(): SaleRepository {
  return useContainer().saleRepo;
}

export function useProductRepo(): ProductRepository {
  return useContainer().productRepo;
}

export function useCostCodeRepo(): CostCodeRepository {
  return useContainer().costCodeRepo;
}

export function useUserRepo(): UserRepository {
  return useContainer().userRepo;
}

export function useActivityLogRepo(): ActivityLogRepository {
  return useContainer().activityLogRepo;
}

export function useSupplierRepo(): SupplierRepository {
  return useContainer().supplierRepo;
}

export function useCategoryRepo(): CategoryRepository {
  return useContainer().categoryRepo;
}

export function useMechanicRepo(): MechanicRepository {
  return useContainer().mechanicRepo;
}

export function useJobOrderRepo(): JobOrderRepository {
  return useContainer().jobOrderRepo;
}

export function useReceivingRepo(): ReceivingRepository {
  return useContainer().receivingRepo;
}

export function useEmployeeRepo(): EmployeeRepository {
  return useContainer().employeeRepo;
}

export function usePayslipRepo(): PayslipRepository {
  return useContainer().payslipRepo;
}

export function useHrSettingsRepo(): HrSettingsRepository {
  return useContainer().hrSettingsRepo;
}

export function useExpenseRepo(): ExpenseRepository {
  return useContainer().expenseRepo;
}

export function useVoidRequestRepo(): VoidRequestRepository {
  return useContainer().voidRequestRepo;
}

export function usePurchaseOrderRepo() {
  return useContainer().purchaseOrderRepo;
}

export function useShopTimezoneRepo(): ShopTimezoneRepository {
  return useContainer().shopTimezoneRepo;
}

export function useDrawerStateRepo(): DrawerStateRepository {
  return useContainer().drawerStateRepo;
}

export function useShopFeeRepo(): ShopFeeRepository {
  return useContainer().shopFeeRepo;
}

export function useMotorcycleModelRepo(): MotorcycleModelRepository {
  return useContainer().motorcycleModelRepo;
}
