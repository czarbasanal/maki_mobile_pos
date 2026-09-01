// /settings/timezone — the shop-wide timezone stored in settings/general.
//
// The offset written here drives the business day on every device AND the
// Firestore rules' phDay(), so this is the single place the shop's clock is
// defined. Mirrors HrSettingsPage's load→edit→save shape.

import { useEffect, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { CheckCircleIcon, ExclamationTriangleIcon } from '@heroicons/react/24/outline';
import { useShopTimezoneRepo } from '@/infrastructure/di/container';
import { LoadingView, Spinner } from '@/presentation/components/common/LoadingView';
import { ErrorView } from '@/presentation/components/common/ErrorView';
import { PageHeader } from '@/presentation/features/settings/PageHeader';
import { useAuthStore } from '@/presentation/stores/authStore';
import { UserRole } from '@/domain/enums';
import {
  formatInShopZone,
  setAmbientShopTimezone,
  type ShopTimezone,
} from '@/domain/time/shopTime';
import { SHOP_TIMEZONES, formatOffset, shopTimezoneById } from '@/domain/time/shopTimezones';

export function TimezoneSettingsPage() {
  useEffect(() => {
    document.title = 'Time & timezone · MAKI POS Admin';
  }, []);

  const repo = useShopTimezoneRepo();
  const queryClient = useQueryClient();
  const user = useAuthStore((s) => s.user);
  // Anyone with viewSettings can look at the shop clock; only an admin may
  // change it — the same split the mobile screen uses.
  const isAdmin = user?.role === UserRole.admin;

  const {
    data: stored,
    isLoading,
    error,
  } = useQuery({
    queryKey: ['shopTimezone'],
    queryFn: () => repo.get(),
  });

  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [saveSuccess, setSaveSuccess] = useState(false);

  const save = useMutation<void, Error, ShopTimezone>({
    mutationFn: (next) => repo.save(next, user?.id ?? ''),
    onSuccess: (_data, next) => {
      queryClient.setQueryData(['shopTimezone'], next);
      // The container's watch() will do this too; setting it here means the
      // clock line below is right immediately rather than one snapshot later.
      setAmbientShopTimezone(next);
      setSelectedId(null);
      setSaveSuccess(true);
      setTimeout(() => setSaveSuccess(false), 4000);
    },
  });

  if (error) {
    return <ErrorView title="Could not load the shop timezone" message={error.message} />;
  }
  if (isLoading || !stored) return <LoadingView label="Loading timezone…" />;

  const activeId = selectedId ?? stored.timezoneId;
  const active = shopTimezoneById(activeId);
  const dirty = activeId !== stored.timezoneId;

  const onSave = () => {
    if (!active || !dirty || !isAdmin) return;
    setSaveSuccess(false);
    save.mutate({ timezoneId: active.id, offsetMinutes: active.offsetMinutes });
  };

  return (
    <div className="space-y-tk-xl">
      <div className="flex flex-wrap items-end justify-between gap-tk-md">
        <PageHeader />
        {isAdmin ? (
        <button
          type="button"
          onClick={onSave}
          disabled={!dirty || save.isPending}
          className="flex items-center gap-tk-xs rounded-md bg-light-text px-tk-md py-tk-sm text-bodySmall font-semibold text-light-background hover:bg-primary-dark disabled:opacity-60"
        >
          {save.isPending ? <Spinner className="h-3.5 w-3.5" /> : null}
          Save
        </button>
        ) : null}
      </div>

      {saveSuccess ? (
        <div className="flex items-center gap-tk-sm rounded-md border border-success-light bg-success-light/40 px-tk-md py-tk-sm text-bodySmall text-success-dark">
          <CheckCircleIcon className="h-4 w-4 text-success" />
          Shop timezone saved.
        </div>
      ) : null}

      {save.error ? (
        <div className="rounded-md border border-error-light bg-error-light/40 px-tk-md py-tk-sm text-bodySmall text-error-dark">
          {save.error.message}
        </div>
      ) : null}

      <section className="space-y-tk-md">
        <div className="max-w-md space-y-tk-md rounded-lg border border-light-hairline bg-light-card p-tk-md">
          <div>
            <p className="text-bodySmall text-light-text-secondary">Shop time now</p>
            <p className="text-body font-semibold text-light-text">
              {formatInShopZone(
                new Date(),
                { dateStyle: 'full', timeStyle: 'short' },
                stored.timezoneId,
              )}
            </p>
            <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
              {shopTimezoneById(stored.timezoneId)?.label ?? stored.timezoneId} · UTC
              {formatOffset(stored.offsetMinutes)}
            </p>
          </div>

          <div>
            <label
              htmlFor="shop-timezone"
              className="mb-tk-xs block text-bodySmall text-light-text-secondary"
            >
              Shop timezone
            </label>
            <select
              id="shop-timezone"
              value={activeId}
              disabled={!isAdmin}
              onChange={(e) => setSelectedId(e.target.value)}
              className="w-full rounded-md border border-light-border bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text outline-none focus:border-light-text"
            >
              {SHOP_TIMEZONES.map((tz) => (
                <option key={tz.id} value={tz.id}>
                  {tz.label} ({formatOffset(tz.offsetMinutes)})
                </option>
              ))}
            </select>
            <p className="mt-tk-xs text-xs text-light-text-hint">
              Only zones without daylight saving are listed — the security rules compare a fixed
              offset.
            </p>
          </div>
        </div>

        <div className="flex max-w-md items-start gap-tk-sm rounded-md border border-light-hairline bg-light-card px-tk-md py-tk-sm text-bodySmall text-light-text-secondary">
          <ExclamationTriangleIcon className="mt-[2px] h-4 w-4 shrink-0" />
          <span>
            Changing this affects every device. Phones running an older app version will stop
            recording sales correctly until they update.
          </span>
        </div>
      </section>
    </div>
  );
}
