import { useEffect, useMemo, useRef, useState, type ChangeEvent, type FormEvent, type ReactNode } from 'react';
import { Link, useNavigate, useParams, generatePath } from 'react-router-dom';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { z } from 'zod';
import { AdjustmentsHorizontalIcon, ArrowLeftIcon, TrashIcon } from '@heroicons/react/24/outline';
import { useProduct } from '@/presentation/hooks/useProduct';
import {
  useCreateProduct,
  useCreateVariation,
  useDeactivateProduct,
  useUpdateProduct,
} from '@/presentation/hooks/useProductMutations';
import { useActiveCategories } from '@/presentation/hooks/useCategories';
import { useSuppliers } from '@/presentation/hooks/useSuppliers';
import { useCostCode } from '@/presentation/hooks/useCostCode';
import { useProductRepo, useCategoryRepo } from '@/infrastructure/di/container';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { CategoryKind } from '@/domain/categories/categoryKind';
import { priceHistoryReason } from '@/domain/products/priceHistoryReason';
import { costsDiffer } from '@/domain/products/costVariation';
import { composeAutoSku, matchesAutoPattern, displaySku } from '@/domain/products/sku';
import { validateSellingOptions } from '@/domain/products/sellingOptions';
import { productDuplicateKey } from '@/domain/products/nameKey';
import {
  encodeCostCode,
  type Category,
  type Product,
  type SellingOption,
  type Supplier,
} from '@/domain/entities';
import type { ProductUpdateInput } from '@/domain/repositories/ProductRepository';
import { SellingOptionsEditor } from './SellingOptionsEditor';
import { AdjustStockDialog } from './AdjustStockDialog';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { Dialog } from '@/presentation/components/common/Dialog';
import { ProductImage } from '@/presentation/components/common/ProductImage';
import { RoutePaths } from '@/presentation/router/routePaths';
import { cn } from '@/core/utils/cn';
import Cropper, { type Area } from 'react-easy-crop';
import { getCroppedBlob } from '@/core/utils/cropImage';

// Required numeric: a blank input must error, not silently coerce to 0
// (Number('') === 0). Map blank -> NaN so z.number rejects it.
const reqNumber = (msg: string, int = false) =>
  z.preprocess(
    (v) => (typeof v === 'string' ? (v.trim() === '' ? NaN : Number(v)) : v),
    (int
      ? z.number({ invalid_type_error: msg }).int('Whole number')
      : z.number({ invalid_type_error: msg })
    ).min(0, 'Must be ≥ 0'),
  );

const schema = z.object({
  name: z.string().trim().min(1, 'Name is required'),
  sku: z
    .string()
    .trim()
    .min(1, 'SKU is required')
    .max(50, 'Max 50 characters')
    .regex(/^[A-Za-z0-9-]+$/, 'Use only letters, numbers, and hyphens'),
  cost: reqNumber('Cost is required'),
  price: reqNumber('Price is required'),
  quantity: reqNumber('Quantity is required', true),
  reorderLevel: reqNumber('Reorder level is required', true),
  unit: z.string().trim().min(1, 'Unit is required'),
  category: z.string().optional().or(z.literal('')),
  supplierId: z.string().optional().or(z.literal('')),
  notes: z.string().trim().optional().or(z.literal('')),
});
type FormValues = z.infer<typeof schema>;

const blank = (s: string | undefined) => (s && s.trim() ? s.trim() : null);

function withCurrent(names: string[], current: string | null): string[] {
  if (current && !names.includes(current)) return [current, ...names];
  return names;
}

interface InventoryFormPageProps {
  /** Rendered inside the product drawer: the drawer supplies the title, close
   *  button and padding, so the form drops its own page chrome and returns to
   *  the product view rather than the list. */
  embedded?: boolean;
}

export function InventoryFormPage({ embedded = false }: InventoryFormPageProps = {}) {
  const { id } = useParams<{ id: string }>();
  const isEditing = !!id;
  // Embedded, the form sits over the product view it was opened from — going
  // back to the list would throw away more context than the user asked to
  // leave.
  const exitTo = embedded && id ? generatePath(RoutePaths.productDetail, { id }) : RoutePaths.inventory;
  const navigate = useNavigate();
  const repo = useProductRepo();
  const categoryRepo = useCategoryRepo();
  const authUser = useAuthStore((s) => s.user);
  const isAdmin = authUser?.role === UserRole.admin;
  // Mobile parity: cashiers may change ONLY the name and image. Everything
  // else is disabled here AND rebased onto a fresh read at save time.
  const nameOnly =
    !!authUser &&
    hasPermission(authUser.role, Permission.editProductNameOnly) &&
    !hasPermission(authUser.role, Permission.editProductLimited) &&
    !hasPermission(authUser.role, Permission.editProduct);
  const canEditStock =
    !!authUser &&
    (hasPermission(authUser.role, Permission.editProduct) ||
      hasPermission(authUser.role, Permission.editProductLimited));
  const canDeleteProduct =
    !!authUser && hasPermission(authUser.role, Permission.deleteProduct);
  // Per-item cost is admin-only (viewProductCost; password-gated on the
  // phone). In EDIT mode the field would display the STORED figure, so it is
  // hidden from everyone else; in CREATE mode it stays — the author is typing
  // a number they already know, and rules allow create-time cost for staff.
  const canSeeCost =
    !!authUser && hasPermission(authUser.role, Permission.viewProductCost);

  const { data: target, isLoading, error } = useProduct(id);
  const update = useUpdateProduct();
  const create = useCreateProduct();
  const createVariation = useCreateVariation();
  const [adjustOpen, setAdjustOpen] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const deactivate = useDeactivateProduct();
  /** Open when a typed SKU collided with a product carrying a different cost. */
  const [variationDialog, setVariationDialog] = useState<{
    open: boolean;
    existing: Product | null;
    cost: number;
    costCode: string;
    nextSku: string;
  }>({ open: false, existing: null, cost: 0, costCode: '', nextSku: '' });
  /** Open when the typed name+category already matches an active product —
   *  the auto-SKU flow never produces a SKU collision, so this is the actual
   *  gate that catches an accidental duplicate part. */
  const [dupDialog, setDupDialog] = useState<{
    open: boolean;
    existing: Product | null;
    values: FormValues | null;
  }>({ open: false, existing: null, values: null });
  const { data: productCats } = useActiveCategories(CategoryKind.product);
  const { data: units } = useActiveCategories(CategoryKind.unit);
  const { data: suppliers } = useSuppliers();
  const { data: costCodeMapping } = useCostCode();

  const [autoSku, setAutoSku] = useState(true);
  const [skuHint, setSkuHint] = useState<string | null>(
    'Pick a category to generate the SKU.',
  );
  const [loadNotice, setLoadNotice] = useState<string | null>(null);
  const [barcodes, setBarcodes] = useState<string[]>([]);
  // Seeded from the product being edited; empty for a new product.
  // Admin-only in both modes (see the "Selling options" Section below) —
  // unrestricted at creation, same posture as `price` (Task 13).
  const [sellingOptions, setSellingOptions] = useState<SellingOption[]>([]);
  const [barcodeInput, setBarcodeInput] = useState('');
  const [barcodeError, setBarcodeError] = useState<string | null>(null);
  const [imageBlob, setImageBlob] = useState<Blob | null>(null);
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [imageRemoved, setImageRemoved] = useState(false);
  const [cropSrc, setCropSrc] = useState<string | null>(null);
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<Area | null>(null);
  const [skuDialog, setSkuDialog] = useState<{ open: boolean; count: number; values: FormValues | null }>(
    { open: false, count: 0, values: null },
  );
  // Monotonic token guarding the async peekNextSequence race: a stale
  // response (superseded by a later category switch, an auto-generate
  // toggle, or a manual edit) must not clobber the SKU field.
  const skuPeekToken = useRef(0);

  const {
    register,
    handleSubmit,
    reset,
    setError,
    setValue,
    getValues,
    watch,
    formState: { errors, isSubmitting },
  } = useForm<FormValues>({
    resolver: zodResolver(schema),
    defaultValues: {
      name: '', sku: '', cost: 0, price: 0, quantity: 0, reorderLevel: 0,
      unit: 'pcs', category: '', supplierId: '', notes: '',
    },
  });

  useEffect(() => {
    document.title = isEditing
      ? target
        ? `Edit ${target.name} · Inventory`
        : 'Edit product'
      : 'New product · Inventory';
  }, [isEditing, target]);

  useEffect(() => {
    if (!target) return;
    reset({
      name: target.name,
      sku: target.sku,
      cost: target.cost,
      price: target.price,
      quantity: target.quantity,
      reorderLevel: target.reorderLevel,
      unit: target.unit,
      category: target.category ?? '',
      supplierId: target.supplierId ?? '',
      notes: target.notes ?? '',
    });
    setBarcodes(target.barcodes);
    setSellingOptions(target.sellingOptions);
  }, [target, reset]);

  useEffect(() => {
    return () => { if (imagePreview) URL.revokeObjectURL(imagePreview); };
  }, [imagePreview]);

  const categoryOptions = useMemo(
    () => withCurrent((productCats ?? []).map((c) => c.name), target?.category ?? null),
    [productCats, target?.category],
  );
  const unitOptions = useMemo(
    () => withCurrent((units ?? []).map((u) => u.name), target?.unit ?? null),
    [units, target?.unit],
  );
  const supplierOptions = useMemo(() => {
    const active = (suppliers ?? []).filter((s) => s.isActive);
    if (target?.supplierId && !active.some((s) => s.id === target.supplierId)) {
      const saved = (suppliers ?? []).find((s) => s.id === target.supplierId);
      if (saved) return [saved, ...active];
      // Suppliers not loaded yet (or the supplier doc is gone): synthesize an
      // option from the product's own snapshot so the saved selection always
      // has an option to land on — the category/unit selects get this via
      // withCurrent. Without it the native select coerces to '' and a save
      // would silently wipe the product's supplier.
      return [
        {
          id: target.supplierId,
          name: target.supplierName ?? target.supplierId,
          isActive: true,
        } as Supplier,
        ...active,
      ];
    }
    return active;
  }, [suppliers, target?.supplierId, target?.supplierName]);

  if (isEditing && error) {
    return <ErrorView title="Could not load product" message={error.message} />;
  }
  if (isEditing && (isLoading || !target)) {
    return <LoadingView label="Loading product…" />;
  }

  const submitting = isSubmitting || update.isPending || create.isPending;
  const mutationError = update.error?.message ?? create.error?.message ?? null;
  const skuLocked = (!isEditing && autoSku) || (isEditing && nameOnly);
  // Only admins can SEE (and fix) the selling-options editor, and every
  // non-admin save drops the key anyway — so only admins carry the
  // validation lock. Otherwise one malformed stored option would silently
  // dead-end staff/cashier saves behind a section they cannot render.
  const sellingOptionsError = isAdmin ? validateSellingOptions(sellingOptions) : null;

  /** Looks up the active product category matching `name` (case-sensitive,
   *  mirrors the dropdown's exact-name matching). */
  const categoryEntityForName = (name: string): Category | undefined =>
    (productCats ?? []).find((c) => c.name === name);

  /** Re-derives the SKU for `category` when auto-generate is on (`autoOn`
   *  passed explicitly rather than read from state, since this can be invoked
   *  in the same handler that just flipped the checkbox). No-op when editing.
   *  A coded category peeks the next sequence and composes `code+sequence`;
   *  anything else — no category, no code, or a failed peek — leaves the
   *  field EMPTY with an explanatory hint. It must never fall back to the old
   *  name-based format. `skuPeekToken` guards a stale response from
   *  clobbering the field after a later switch superseded it. */
  const applyCategoryForSku = (category: Category | undefined, autoOn: boolean) => {
    if (isEditing || !autoOn) return;
    const token = ++skuPeekToken.current;
    const code = category?.code;
    if (code === undefined) {
      setValue('sku', '', { shouldValidate: false });
      setSkuHint(
        category === undefined
          ? 'Pick a category to generate the SKU.'
          : 'This category has no code — pick another, or turn off auto-generate and type a SKU.',
      );
      return;
    }
    categoryRepo
      .peekNextSequence(code)
      .then((sequence) => {
        if (token !== skuPeekToken.current) return;
        if (categoryEntityForName(getValues('category') ?? '')?.code !== code) return;
        setValue('sku', composeAutoSku(code, sequence), { shouldValidate: true });
        setSkuHint(null);
      })
      .catch(() => {
        if (token !== skuPeekToken.current) return;
        setValue('sku', '', { shouldValidate: false });
        // The category DOES have a code — the lookup failed. Saying "no code"
        // here would send the admin hunting for a settings problem that
        // doesn't exist.
        setSkuHint(
          "Couldn't reach the server — try again, or turn off auto-generate and type a SKU.",
        );
      });
  };

  /** Category code to hand `useCreateProduct` for the atomic peek+claim, or
   *  undefined for a plain (non-claiming) create. Only fires when
   *  auto-generate is on AND the SKU currently in `values` still matches
   *  that category's coded pattern — a manual edit after the last peek
   *  silently falls back to undefined, same as an uncoded category. */
  /**
   * Decides whether a rejected duplicate SKU is really a cost variation.
   *
   * Resolves the product holding that SKU's claim (via the NORMALIZED key, so
   * a case-different entry can't be missed) and opens the confirm dialog when
   * its cost differs from the one just entered. Returns true when it took
   * over, leaving the caller to show the plain duplicate error otherwise.
   */
  const offerVariation = async (
    sku: string,
    cost: number,
    costCode: string,
  ): Promise<boolean> => {
    let existing: Product | null = null;
    try {
      existing = await repo.findBySkuClaim(sku);
    } catch {
      // A failed lookup must not swallow the duplicate error the user needs.
      return false;
    }
    if (!existing || !costsDiffer(existing.cost, cost)) return false;

    const base = existing.baseSku ?? existing.sku;
    let nextSku = `${base}-1`;
    try {
      nextSku = `${base}-${await repo.nextVariationNumber(base)}`;
    } catch {
      // Preview only — createVariation allocates the real number itself, and
      // re-allocates if a concurrent writer takes it first.
    }
    // Clear the failed create so its "SKU already exists" banner stops
    // contradicting the dialog now offering a way forward.
    create.reset();
    setVariationDialog({ open: true, existing, cost, costCode, nextSku });
    return true;
  };

  /** Declining the offer: the save still didn't happen, so put the reason back. */
  const declineVariation = () => {
    setVariationDialog((v) => ({ ...v, open: false }));
    setError('sku', {
      type: 'duplicate',
      message: 'A product with this SKU already exists',
    });
  };

  const autoSkuCategoryCodeForSubmit = (values: FormValues): string | undefined => {
    if (!autoSku) return undefined;
    const code = categoryEntityForName(values.category ?? '')?.code;
    if (code === undefined) return undefined;
    return matchesAutoPattern(values.sku.trim(), code) ? code : undefined;
  };

  const commitBarcode = (raw: string) => {
    const code = raw.trim();
    if (!code) return;
    if (barcodes.includes(code)) {
      setBarcodeError('Already added');
      return;
    }
    setBarcodes([...barcodes, code]);
    setBarcodeInput('');
    setBarcodeError(null);
  };
  const removeBarcode = (code: string) =>
    setBarcodes((prev) => prev.filter((b) => b !== code));

  const onPickFile = (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = ''; // allow re-picking the same file
    if (!file) return;
    setCropSrc(URL.createObjectURL(file));
    setCrop({ x: 0, y: 0 });
    setZoom(1);
  };
  const closeCrop = () => {
    if (cropSrc) URL.revokeObjectURL(cropSrc);
    setCropSrc(null);
  };
  const confirmCrop = async () => {
    if (!cropSrc || !croppedAreaPixels) return;
    try {
      const blob = await getCroppedBlob(cropSrc, croppedAreaPixels);
      setImageBlob(blob);
      setImagePreview(URL.createObjectURL(blob));
      setImageRemoved(false);
    } catch {
      setLoadNotice('Could not process that image — try a different file.');
    } finally {
      closeCrop();
    }
  };
  const removeImage = () => {
    setImageBlob(null);
    setImagePreview(null);
    setImageRemoved(true);
  };
  const shownImage = imagePreview ?? (!imageRemoved ? target?.imageUrl ?? null : null);

  /** Force-uppercase an input in place (cursor preserved) BEFORE RHF reads it —
   * catalog convention is all-caps names/SKUs. */
  const upperizeInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    const el = e.target;
    const start = el.selectionStart;
    const end = el.selectionEnd;
    el.value = el.value.toUpperCase();
    if (start !== null && end !== null) el.setSelectionRange(start, end);
  };

  const nameField = register('name');
  const skuField = register('sku', {
    onChange: () => {
      if (update.error) update.reset();
      if (create.error) create.reset();
    },
  });

  const resolveSupplier = (supplierId: string) => {
    const idOut = supplierId || null;
    const found = (suppliers ?? []).find((s) => s.id === idOut);
    if (idOut === null) return { id: null, name: null };
    if (found) return { id: idOut, name: found.name };
    if (isEditing && idOut === target?.supplierId) return { id: idOut, name: target?.supplierName ?? null };
    return { id: idOut, name: null };
  };

  /**
   * The actual create-a-new-product write. Extracted so both the normal
   * submit path and the duplicate-name dialog's "Save as a separate
   * product" button can reach it — the dialog runs AFTER the duplicate-name
   * gate has already fired once, so it must not re-run that gate.
   */
  const submitCreate = async (values: FormValues) => {
    if (!costCodeMapping) {
      setLoadNotice('Cost-code mapping is still loading — try again in a moment.');
      return;
    }
    const pending = barcodeInput.trim();
    const allBarcodes = pending && !barcodes.includes(pending) ? [...barcodes, pending] : barcodes;
    const costNum = Number(values.cost);
    const priceNum = Number(values.price);
    const supplier = resolveSupplier(values.supplierId ?? '');
    try {
      await create.mutateAsync({
        sku: values.sku.trim(),
        name: values.name.trim(),
        costCode: encodeCostCode(costCodeMapping, costNum),
        cost: costNum,
        price: priceNum,
        quantity: Number(values.quantity),
        reorderLevel: Number(values.reorderLevel),
        unit: values.unit.trim() || 'pcs',
        supplierId: supplier.id,
        supplierName: supplier.name,
        barcodes: allBarcodes,
        category: blank(values.category),
        notes: blank(values.notes),
        imageBlob,
        autoSkuCategoryCode: autoSkuCategoryCodeForSubmit(values),
        // Unrestricted at creation (Task 13's posture, same as `price`) — no
        // role check needed here, unlike the edit-mode patch above.
        sellingOptions,
      });
      navigate(exitTo);
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Save failed';
      if (msg.toLowerCase().includes('sku already exists')) {
        // A SKU taken at a DIFFERENT cost is a cost variation waiting to
        // happen, not a typo — offer to spawn `<base>-N` rather than just
        // blocking the save. An identical cost stays a plain duplicate.
        if (await offerVariation(values.sku.trim(), costNum, encodeCostCode(costCodeMapping, costNum))) {
          return;
        }
        setError('sku', { type: 'duplicate', message: msg });
      } else if (msg.toLowerCase().includes('barcode already exists')) setBarcodeError(msg);
    }
  };

  const doSave = async (values: FormValues) => {
    setLoadNotice(null);
    // Auto-commit a barcode typed but not yet added (mirrors mobile's save flow).
    const pending = barcodeInput.trim();
    const allBarcodes = pending && !barcodes.includes(pending) ? [...barcodes, pending] : barcodes;
    const costNum = Number(values.cost);
    const priceNum = Number(values.price);
    const supplier = resolveSupplier(values.supplierId ?? '');

    if (isEditing && target) {
      const costChanged = Math.abs(costNum - target.cost) > 0.01;
      if (costChanged && !costCodeMapping) {
        setLoadNotice('Cost-code mapping is still loading — try again in a moment.');
        return;
      }
      const costCode = costChanged ? encodeCostCode(costCodeMapping!, costNum) : target.costCode;
      const reason = priceHistoryReason(target.cost, target.price, costNum, priceNum);
      const patch: ProductUpdateInput = {
        name: values.name.trim(),
        sku: values.sku.trim(),
        category: blank(values.category),
        cost: costNum,
        costCode,
        price: priceNum,
        reorderLevel: Number(values.reorderLevel),
        unit: values.unit.trim() || 'pcs',
        supplierId: supplier.id,
        supplierName: supplier.name,
        barcodes: allBarcodes,
        notes: blank(values.notes),
        // Always included in the patch — same as every other field here.
        // Whether it actually reaches Firestore is decided one layer down
        // (useUpdateProduct's includeSellingOptions, gated on the actor's
        // role per Task 13), not by this form. For a non-admin this is just
        // the target's own unchanged value (the editor is hidden from them),
        // so it's a safe no-op even before that gate drops it.
        sellingOptions,
      };
      try {
        await update.mutateAsync({
          id: target.id,
          oldSku: target.sku,
          oldBarcodes: target.barcodes,
          patch,
          priceChange: reason ? { price: priceNum, cost: costNum, reason } : null,
          image: imageBlob
            ? { kind: 'replace', blob: imageBlob }
            : imageRemoved
              ? { kind: 'remove' }
              : { kind: 'keep' },
        });
        navigate(exitTo);
      } catch (e) {
        const msg = e instanceof Error ? e.message : 'Save failed';
        if (msg.toLowerCase().includes('sku already exists')) setError('sku', { type: 'duplicate', message: msg });
        else if (msg.toLowerCase().includes('barcode already exists')) setBarcodeError(msg);
      }
      return;
    }

    // Duplicate NAME gate. Runs before create, unlike the SKU gate which can
    // only fire after Firestore rejects a claim — the auto-SKU flow never
    // produces a SKU collision, which is why duplicates accumulated. `target`
    // is always undefined on this path (it's only populated in edit mode,
    // which returned above), so this can never flag a product against
    // itself.
    const dupKey = productDuplicateKey(values.name, values.category ?? null);
    let dupExisting: Product | null = null;
    try {
      dupExisting = await repo.findByNameKey(dupKey);
    } catch {
      // A failed lookup must never block a legitimate save.
      dupExisting = null;
    }
    if (dupExisting && dupExisting.id !== target?.id) {
      setDupDialog({ open: true, existing: dupExisting, values });
      return;
    }

    await submitCreate(values);
  };

  const onSubmit = async (values: FormValues) => {
    // Not covered by the zod schema (sellingOptions lives in its own local
    // state, not an RHF field) — handleSubmit's own validation can't block
    // it, so guard here too. The submit button is also disabled while this
    // is truthy, but a native Enter-to-submit bypasses a disabled button, so
    // this is the actual enforcement point.
    if (sellingOptionsError) return;
    if (isEditing && target && values.sku.trim() !== target.sku) {
      const count = await repo.countSkuVariations(target.sku);
      setSkuDialog({ open: true, count, values });
      return;
    }
    await doSave(values);
  };

  const onFormSubmit = (e: FormEvent<HTMLFormElement>) => {
    void handleSubmit(onSubmit)(e);
  };

  return (
    <div className={embedded ? 'space-y-tk-lg' : 'space-y-tk-xl px-tk-xl py-tk-lg'}>
      <header className="space-y-tk-sm">
        {/* The drawer already shows the product name and a close button, so
            embedding these would say the same thing twice. */}
        {!embedded ? (
          <Link
            to={RoutePaths.inventory}
            className="inline-flex items-center gap-tk-xs text-bodySmall text-light-text-secondary hover:text-light-text"
          >
            <ArrowLeftIcon className="h-3.5 w-3.5" /> Inventory
          </Link>
        ) : null}
        {!embedded ? (
          <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
            {isEditing ? 'Edit product' : 'New product'}
          </h1>
        ) : null}
      </header>

      {mutationError && !errors.sku ? (
        <p className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {mutationError}
        </p>
      ) : null}
      {loadNotice ? (
        <p className="rounded-md border border-warning-light bg-warning-light/40 px-tk-md py-tk-sm text-bodySmall text-warning-dark">
          {loadNotice}
        </p>
      ) : null}

      <form onSubmit={onFormSubmit} className="space-y-tk-lg" noValidate>
        {isEditing && nameOnly ? (
          <div className="rounded-md border border-light-hairline bg-light-subtle px-tk-md py-tk-sm text-bodySmall text-light-text-secondary">
            You can edit the product name and image.
          </div>
        ) : null}

        <Section title="Identity">
          <Field label="Name" error={errors.name?.message}
            input={
              <input
                type="text"
                className={inputCls(!!errors.name)}
                {...nameField}
                onChange={(e) => { upperizeInput(e); void nameField.onChange(e); }}
              />
            } />

          {!isEditing ? (
            <label className="flex items-center gap-tk-sm text-bodySmall text-light-text">
              <input
                type="checkbox"
                checked={autoSku}
                onChange={(e) => {
                  const on = e.target.checked;
                  setAutoSku(on);
                  // Cancel any in-flight peek when toggling.
                  skuPeekToken.current++;
                  if (on) {
                    applyCategoryForSku(categoryEntityForName(getValues('category') ?? ''), true);
                  }
                }}
              />
              Auto-generate SKU from category
            </label>
          ) : null}

          <Field label="SKU" error={errors.sku?.message}
            input={
              <input
                type="text"
                readOnly={skuLocked}
                className={cn(inputCls(!!errors.sku), skuLocked && 'bg-light-subtle text-light-text-secondary')}
                {...skuField}
                onChange={(e) => { upperizeInput(e); void skuField.onChange(e); }}
              />
            } />
          {skuLocked && skuHint ? (
            <p className="text-[12px] text-light-text-hint">{skuHint}</p>
          ) : null}
          {isEditing ? (
            <p className="text-[12px] text-light-text-hint">
              Changing the SKU keeps past sales &amp; receiving records on the old code and re-points linked variations.
            </p>
          ) : null}

          <Field label="Barcodes" error={barcodeError ?? undefined}
            input={
              <div className="space-y-tk-sm">
                {barcodes.length ? (
                  <div className="flex flex-wrap gap-tk-xs">
                    {barcodes.map((code) => (
                      <span key={code} className="inline-flex items-center gap-tk-xs rounded-full bg-light-subtle px-tk-sm py-[2px] text-[12px] text-light-text">
                        <span className="font-mono">{code}</span>
                        {nameOnly ? null : (
                          <button type="button" onClick={() => removeBarcode(code)} className="text-light-text-hint hover:text-error" aria-label={`Remove ${code}`}>×</button>
                        )}
                      </span>
                    ))}
                  </div>
                ) : null}
                {nameOnly ? null : (
                <div className="flex items-center gap-tk-sm">
                  <input
                    type="text"
                    value={barcodeInput}
                    onChange={(e) => { setBarcodeInput(e.target.value); if (barcodeError) setBarcodeError(null); }}
                    onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); commitBarcode(barcodeInput); } }}
                    placeholder="Add barcode"
                    className={inputCls(false)}
                  />
                  <button type="button" onClick={() => commitBarcode(barcodeInput)}
                    className="inline-flex shrink-0 items-center rounded-md border border-light-border px-tk-md py-[10px] text-bodySmall text-light-text hover:bg-light-subtle">
                    Add
                  </button>
                </div>
                )}
              </div>
            } />

          <Field label="Image"
            input={
              <div className="flex items-center gap-tk-md">
                <ProductImage src={shownImage} alt={target?.name ?? 'Product'} size="md" />
                <div className="flex items-center gap-tk-sm">
                  <label className="cursor-pointer rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">
                    {shownImage ? 'Change' : 'Upload'}
                    <input type="file" accept="image/*" className="hidden" onChange={onPickFile} />
                  </label>
                  {shownImage ? (
                    <button type="button" onClick={removeImage}
                      className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text-secondary hover:bg-light-subtle">
                      Remove
                    </button>
                  ) : null}
                </div>
              </div>
            } />
        </Section>

        <Section title="Pricing">
          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2">
            {!isEditing || canSeeCost ? (
              <Field label="Cost" error={errors.cost?.message}
                input={<input type="number" step="0.01" className={inputCls(!!errors.cost)} {...register('cost')} />} />
            ) : null}
            {/* Staff/cashier may not CHANGE price (rules reject the whole
                update), so editing it would only invite a save that cannot
                succeed. The seeded value still rides the patch unchanged. */}
            <Field label="Price" error={errors.price?.message}
              input={<input type="number" step="0.01" disabled={isEditing && !isAdmin}
                className={inputCls(!!errors.price)} {...register('price')} />} />
          </div>
          {/* The base price stops being directly sellable once a product
              carries selling options — a picker gates every sale instead.
              Say so in plain shop-owner language, not developer jargon. */}
          {sellingOptions.length > 0 ? (
            <p className="text-[12px] text-light-text-hint">
              The POS will ask for a selling option — this price is used for inventory value, not charged directly.
            </p>
          ) : null}
        </Section>

        {/* Admin-only, same as InventoryListPage's totals strip. Shown in
            both create and edit — creation is unrestricted for this field,
            matching how `price` already works (Task 13). */}
        {isAdmin ? (
          <Section title="Selling options">
            <SellingOptionsEditor
              value={sellingOptions}
              onChange={setSellingOptions}
              unitCost={Number(watch('cost')) || 0}
              unit={watch('unit') || 'pcs'}
              showMargin={isAdmin}
              error={sellingOptionsError}
            />
          </Section>
        ) : null}

        {/* Stock moves through an audited adjustment, not by typing over the
            quantity — so the control sits on this section's heading rather
            than among the fields, where it would read as an alternative to
            them. Create mode has no stock to adjust yet. */}
        <Section
          title="Stock & classification"
          action={
            isEditing && target && canEditStock ? (
              <button
                type="button"
                onClick={() => setAdjustOpen(true)}
                className="inline-flex items-center gap-tk-xs rounded-md border border-light-border px-tk-sm py-[4px] text-bodySmall text-light-text hover:bg-light-subtle"
              >
                <AdjustmentsHorizontalIcon className="h-3.5 w-3.5" /> Adjust stock
              </button>
            ) : null
          }
        >
          <div className="grid grid-cols-1 gap-tk-md sm:grid-cols-2">
            {!isEditing ? (
              <Field label="Initial quantity" error={errors.quantity?.message}
                input={<input type="number" className={inputCls(!!errors.quantity)} {...register('quantity')} />} />
            ) : null}
            <Field label="Reorder level" error={errors.reorderLevel?.message}
              input={<input type="number" disabled={nameOnly} className={inputCls(!!errors.reorderLevel)} {...register('reorderLevel')} />} />
            <Field label="Unit" error={errors.unit?.message}
              input={
                <select disabled={nameOnly} className={cn(inputCls(!!errors.unit), 'pr-8')} {...register('unit')}>
                  {unitOptions.map((u) => (<option key={u} value={u}>{u}</option>))}
                </select>
              } />
            <Field label="Category" error={errors.category?.message}
              input={
                <select disabled={nameOnly} className={cn(inputCls(false), 'pr-8')}
                  {...register('category', {
                    onChange: (e) => applyCategoryForSku(categoryEntityForName(e.target.value), autoSku),
                  })}
                >
                  <option value="">(none)</option>
                  {categoryOptions.map((c) => (<option key={c} value={c}>{c}</option>))}
                </select>
              } />
            <Field label="Supplier" error={errors.supplierId?.message}
              input={
                <select disabled={nameOnly} className={cn(inputCls(false), 'pr-8')} {...register('supplierId')}>
                  <option value="">No supplier</option>
                  {supplierOptions.map((s) => (
                    <option key={s.id} value={s.id}>{s.isActive ? s.name : `${s.name} (inactive)`}</option>
                  ))}
                </select>
              } />
          </div>
        </Section>

        <Section title="Notes">
          <Field label="Notes" error={errors.notes?.message}
            input={<textarea rows={3} disabled={nameOnly} className={cn(inputCls(!!errors.notes), 'resize-y leading-relaxed')} {...register('notes')} />} />
        </Section>

        <div className="flex flex-wrap items-center justify-end gap-tk-sm">
          {/* Deleting lives here rather than in the read-only view, so the
              destructive action sits behind the deliberate act of editing.
              Pushed to the far left, away from Save. */}
          {isEditing && target && canDeleteProduct ? (
            <button
              type="button"
              onClick={() => setConfirmDelete(true)}
              className="mr-auto inline-flex items-center gap-tk-xs rounded-md border border-error-light px-tk-md py-tk-sm text-bodySmall text-error-dark hover:bg-error-light/40"
            >
              <TrashIcon className="h-4 w-4" /> Delete
            </button>
          ) : null}
          <Link to={exitTo}
            className="rounded-md px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">
            Cancel
          </Link>
          <button type="submit" disabled={submitting || !!sellingOptionsError}
            className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:cursor-not-allowed disabled:opacity-60">
            {submitting ? <Spinner className="h-3.5 w-3.5" /> : null}
            {submitting ? 'Saving…' : isEditing ? 'Save changes' : 'Create product'}
          </button>
        </div>
      </form>

      <Dialog
        open={skuDialog.open}
        onClose={() => { if (!submitting) setSkuDialog((d) => ({ ...d, open: false })); }}
        title="Change SKU?"
        dismissable={!submitting}
      >
        <div className="space-y-tk-md">
          <p className="text-bodySmall text-light-text">
            <span className="font-mono">{target?.sku}</span>
            <span className="px-tk-sm text-light-text-hint">→</span>
            <span className="font-mono">{skuDialog.values?.sku}</span>
          </p>
          <ul className="list-disc space-y-tk-xs pl-5 text-bodySmall text-light-text-secondary">
            <li>Past sales and receiving records keep their original SKU.</li>
            {skuDialog.count > 0 ? (
              <li>{skuDialog.count} linked variation(s) will be re-pointed to the new SKU.</li>
            ) : null}
          </ul>
          <div className="flex justify-end gap-tk-sm pt-tk-sm">
            <button type="button" disabled={submitting}
              onClick={() => setSkuDialog((d) => ({ ...d, open: false }))}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">
              Cancel
            </button>
            <button type="button" disabled={submitting}
              onClick={async () => {
                const values = skuDialog.values;
                setSkuDialog((d) => ({ ...d, open: false }));
                if (values) await doSave(values);
              }}
              className="inline-flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60">
              {submitting ? <Spinner className="h-3.5 w-3.5" /> : null} Change SKU
            </button>
          </div>
        </div>
      </Dialog>

      <Dialog
        open={variationDialog.open}
        onClose={() => {
          if (!createVariation.isPending) declineVariation();
        }}
        title="SKU already exists"
        dismissable={!createVariation.isPending}
      >
        <div className="space-y-tk-md">
          <p className="text-bodySmall text-light-text">
            “{variationDialog.existing?.name}” is on file at a cost of ₱
            {variationDialog.existing?.cost.toFixed(2)}.
          </p>
          <p className="text-bodySmall text-light-text">
            Create variation{' '}
            <span className="font-mono">{variationDialog.nextSku}</span> at ₱
            {variationDialog.cost.toFixed(2)}?
          </p>
          <p className="text-bodySmall text-light-text-secondary">
            It copies the existing product’s name, price and unit, and starts at 0 stock with
            no barcodes. The name, price, quantity and barcodes you typed will not be saved.
          </p>
          <div className="flex justify-end gap-tk-sm pt-tk-sm">
            <button
              type="button"
              disabled={createVariation.isPending}
              onClick={declineVariation}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
            >
              Cancel
            </button>
            <button
              type="button"
              disabled={createVariation.isPending}
              onClick={async () => {
                const { existing, cost, costCode } = variationDialog;
                if (!existing) return;
                try {
                  await createVariation.mutateAsync({
                    existing,
                    cost,
                    costCode,
                    price: Number(getValues('price')),
                  });
                  setVariationDialog((v) => ({ ...v, open: false }));
                  navigate(exitTo);
                } catch (e) {
                  setVariationDialog((v) => ({ ...v, open: false }));
                  setError('sku', {
                    type: 'duplicate',
                    message: e instanceof Error ? e.message : 'Could not create the variation',
                  });
                }
              }}
              className="inline-flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
            >
              {createVariation.isPending ? <Spinner className="h-3.5 w-3.5" /> : null} Create
              variation
            </button>
          </div>
        </div>
      </Dialog>

      <Dialog
        open={dupDialog.open}
        onClose={() => {
          if (!createVariation.isPending) setDupDialog({ open: false, existing: null, values: null });
        }}
        title="A product with this name already exists"
        dismissable={!createVariation.isPending}
      >
        <div className="space-y-tk-md">
          <p className="text-bodySmall text-light-text">
            “{dupDialog.existing?.name}” ({displaySku(dupDialog.existing?.sku ?? '')}) is already
            on file in {dupDialog.existing?.category ?? 'no category'}, at a cost of ₱
            {dupDialog.existing?.cost.toFixed(2)} and selling at ₱
            {dupDialog.existing?.price.toFixed(2)}.
          </p>
          <p className="text-bodySmall text-light-text-secondary">
            If this is the same part at a new cost, make it a variation — it keeps one item on
            the shelf and one stock history. If it is genuinely a different part, save it
            separately.
          </p>
          <div className="flex flex-wrap justify-end gap-tk-sm">
            <button
              type="button"
              disabled={createVariation.isPending}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
              onClick={() => setDupDialog({ open: false, existing: null, values: null })}
            >
              Cancel
            </button>
            <button
              type="button"
              disabled={createVariation.isPending}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
              onClick={async () => {
                const v = dupDialog.values;
                setDupDialog({ open: false, existing: null, values: null });
                if (v) await submitCreate(v);
              }}
            >
              Save as a separate product
            </button>
            <button
              type="button"
              disabled={createVariation.isPending}
              className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background disabled:opacity-60"
              onClick={async () => {
                const { existing, values: v } = dupDialog;
                if (!existing || !v) {
                  setDupDialog({ open: false, existing: null, values: null });
                  return;
                }
                if (!costCodeMapping) {
                  setDupDialog({ open: false, existing: null, values: null });
                  setLoadNotice('Cost-code mapping is still loading — try again in a moment.');
                  return;
                }
                const costNum = Number(v.cost);
                try {
                  await createVariation.mutateAsync({
                    existing,
                    cost: costNum,
                    costCode: encodeCostCode(costCodeMapping, costNum),
                    price: Number(v.price),
                  });
                  setDupDialog({ open: false, existing: null, values: null });
                  navigate(exitTo);
                } catch (e) {
                  setDupDialog({ open: false, existing: null, values: null });
                  setError('sku', {
                    type: 'duplicate',
                    message: e instanceof Error ? e.message : 'Could not create the variation',
                  });
                }
              }}
            >
              {createVariation.isPending ? <Spinner className="h-3.5 w-3.5" /> : null} Make it a
              variation
            </button>
          </div>
        </div>
      </Dialog>

      {isEditing && target ? (
        <Dialog
          open={confirmDelete}
          onClose={() => { if (!deactivate.isPending) setConfirmDelete(false); }}
          title="Delete Product?"
          dismissable={!deactivate.isPending}
        >
          <div className="space-y-tk-md">
            <p className="text-bodySmall text-light-text-secondary">
              Delete “{target.name}”? This product will be hidden from POS and inventory lists.
              Past sales and receivings that reference it remain intact.
            </p>
            {deactivate.error ? (
              <p className="text-bodySmall text-error-dark">{deactivate.error.message}</p>
            ) : null}
            <div className="flex justify-end gap-tk-sm pt-tk-sm">
              <button
                type="button"
                disabled={deactivate.isPending}
                onClick={() => setConfirmDelete(false)}
                className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={deactivate.isPending}
                onClick={async () => {
                  await deactivate.mutateAsync({ id: target.id, name: target.name, sku: target.sku });
                  setConfirmDelete(false);
                  // The product is hidden from inventory now, so the product
                  // view we came from would show a record the list no longer
                  // carries — go back to the list instead.
                  navigate(RoutePaths.inventory);
                }}
                className="inline-flex items-center gap-tk-xs rounded-md bg-error-dark px-tk-md py-tk-sm text-bodySmall font-semibold text-white hover:opacity-90 disabled:opacity-60"
              >
                {deactivate.isPending ? <Spinner className="h-3.5 w-3.5" /> : null} Delete
              </button>
            </div>
          </div>
        </Dialog>
      ) : null}

      {isEditing && target ? (
        <AdjustStockDialog
          key={adjustOpen ? target.id : 'closed'}
          product={target}
          open={adjustOpen}
          onClose={() => setAdjustOpen(false)}
        />
      ) : null}

      <Dialog open={!!cropSrc} onClose={closeCrop} title="Crop image" dismissable>
        <div className="space-y-tk-md">
          <div className="relative h-64 w-full overflow-hidden rounded-md bg-light-subtle">
            {cropSrc ? (
              <Cropper
                image={cropSrc}
                crop={crop}
                zoom={zoom}
                aspect={1}
                onCropChange={setCrop}
                onZoomChange={setZoom}
                onCropComplete={(_area, areaPixels) => setCroppedAreaPixels(areaPixels)}
              />
            ) : null}
          </div>
          <label className="flex items-center gap-tk-sm text-bodySmall text-light-text">
            Zoom
            <input type="range" min={1} max={3} step={0.1} value={zoom}
              onChange={(e) => setZoom(Number(e.target.value))} className="flex-1" />
          </label>
          <div className="flex justify-end gap-tk-sm">
            <button type="button" onClick={closeCrop}
              className="rounded-md border border-light-border px-tk-md py-tk-sm text-bodySmall text-light-text hover:bg-light-subtle">
              Cancel
            </button>
            <button type="button" onClick={confirmCrop}
              className="rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark">
              Save
            </button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}

function inputCls(hasError: boolean): string {
  return cn(
    'w-full rounded-md border bg-light-card px-tk-md py-[10px] text-bodySmall text-light-text outline-none transition-colors',
    'focus:border-light-text focus:outline focus:outline-1 focus:outline-light-text focus:outline-offset-0',
    hasError ? 'border-error focus:border-error focus:outline-error' : 'border-light-border',
  );
}

function Field({ label, error, input }: { label: string; error?: string; input: ReactNode }) {
  return (
    <label className="block space-y-tk-xs">
      <span className="text-bodySmall font-medium text-light-text">{label}</span>
      {input}
      {error ? <span className="block text-[12px] text-error">{error}</span> : null}
    </label>
  );
}

function Section({
  title,
  action,
  children,
}: {
  title: string;
  /** Optional control sitting opposite the heading, right-aligned. */
  action?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section className="space-y-tk-sm">
      <div className="flex items-center justify-between gap-tk-md">
        <h2 className="text-[11px] font-semibold uppercase tracking-wider text-light-text-hint">{title}</h2>
        {action}
      </div>
      <div className="space-y-tk-md rounded-lg border border-light-hairline bg-light-card p-tk-md">{children}</div>
    </section>
  );
}
