// /admin/settings — settings overview. Mirrors the Flutter settings_screen
// structure: profile section + admin section + general section.

import { useEffect, useState, type ComponentType, type SVGProps } from 'react';
import { Link } from 'react-router-dom';
import {
  ChevronRightIcon,
  ClipboardDocumentListIcon,
  ClockIcon,
  CodeBracketSquareIcon,
  InformationCircleIcon,
  KeyIcon,
  QueueListIcon,
  TagIcon,
  UserIcon,
  UsersIcon,
  WrenchScrewdriverIcon,
} from '@heroicons/react/24/outline';
import { useAuthStore } from '@/presentation/stores/authStore';
import { RoutePaths } from '@/presentation/router/routePaths';
import { ChangePasswordDialog } from './ChangePasswordDialog';
import { EditDisplayNameDialog } from './EditDisplayNameDialog';
import { userRoleDisplayName } from '@/domain/enums';
import { hasPermission, Permission } from '@/domain/permissions/Permission';
import { toneBadgeClasses, type Tone } from '@/core/theme/tones';
import { cn } from '@/core/utils/cn';

export function SettingsPage() {
  const user = useAuthStore((s) => s.user);
  // Each row shows only to holders of its route's permission — the guard
  // would bounce anyone else, so an ungated row is just a dead end.
  const can = (p: Permission) => !!user && hasPermission(user.role, p);
  const [pwOpen, setPwOpen] = useState(false);
  const [pwSuccess, setPwSuccess] = useState(false);
  const [nameOpen, setNameOpen] = useState(false);
  const [nameSuccess, setNameSuccess] = useState(false);

  useEffect(() => {
    document.title = 'Settings · MAKI POS Admin';
  }, []);

  if (!user) return null;

  return (
    <div className="space-y-tk-xl">
      {pwSuccess || nameSuccess ? (
        <div className="rounded-md border border-success-light bg-success-light/40 px-tk-md py-tk-sm text-bodySmall text-success-dark">
          {pwSuccess ? 'Password updated.' : 'Display name updated.'}
        </div>
      ) : null}

      <Section title="My profile">
        <div className="flex items-center gap-tk-md rounded-lg border border-light-hairline bg-light-card p-tk-md">
          <span className="grid h-12 w-12 shrink-0 place-items-center rounded-full bg-primary-dark text-bodyMedium font-semibold text-white">
            {user.email[0]?.toUpperCase() ?? '?'}
          </span>
          <div className="min-w-0 flex-1">
            <div className="text-bodyMedium font-semibold text-light-text">
              {user.displayName || user.email}
            </div>
            <div className="text-bodySmall text-light-text-secondary">{user.email}</div>
            <div className="mt-tk-xs inline-flex rounded-full bg-light-subtle px-tk-sm py-[1px] text-[11px] font-semibold uppercase tracking-wider text-light-text-secondary">
              {userRoleDisplayName[user.role]}
            </div>
          </div>
        </div>

        <Row
          icon={UserIcon}
          tone="blue"
          title="Display name"
          subtitle={user.displayName || '—'}
          onClick={() => setNameOpen(true)}
        />
        <Row
          icon={KeyIcon}
          tone="red"
          title="Change password"
          subtitle="Update your sign-in password"
          onClick={() => setPwOpen(true)}
        />
      </Section>

      <Section title="Administration">
        {can(Permission.viewUsers) ? (
          <Row
            to={RoutePaths.users}
            icon={UsersIcon}
            tone="blue"
            title="User management"
            subtitle="Add, edit, and manage users"
          />
        ) : null}
        {can(Permission.viewUserLogs) ? (
          <Row
            to={RoutePaths.userLogs}
            icon={ClockIcon}
            tone="violet"
            title="Activity logs"
            subtitle="View user activity and audit trail"
          />
        ) : null}
        {can(Permission.editCostCodeMapping) ? (
          <Row
            to={RoutePaths.costCodeSettings}
            icon={CodeBracketSquareIcon}
            tone="orange"
            title="Cost code settings"
            subtitle="Configure cost encoding"
          />
        ) : null}
        {can(Permission.editLists) ? (
          <Row
            to={RoutePaths.manageLists}
            icon={QueueListIcon}
            tone="blue"
            title="Manage lists"
            subtitle="Categories, units, and other dropdown values"
          />
        ) : null}
        {can(Permission.editLists) ? (
          <Row
            to={RoutePaths.mechanics}
            icon={WrenchScrewdriverIcon}
            tone="orange"
            title="Mechanics"
            subtitle="Mechanics for labor on service sales"
          />
        ) : null}
        {can(Permission.editLists) ? (
          <Row
            to={RoutePaths.productTags}
            icon={TagIcon}
            tone="orange"
            title="Product tags"
            subtitle="Color-coded markers shown on inventory"
          />
        ) : null}
        {can(Permission.editLists) ? (
          <Row
            to={RoutePaths.adjustmentReasons}
            icon={ClipboardDocumentListIcon}
            tone="yellow"
            title="Adjustment reasons"
            subtitle="Why stock was corrected — shown in the adjust-stock dialog"
          />
        ) : null}
      </Section>

      <Section title="General">
        <Row
          to={RoutePaths.timezoneSettings}
          icon={ClockIcon}
          tone="green"
          title="Time & timezone"
          subtitle="Business day and report dates"
        />
        <Row
          to={RoutePaths.about}
          icon={InformationCircleIcon}
          tone="green"
          title="About"
          subtitle="App version and info"
        />
      </Section>

      <ChangePasswordDialog
        open={pwOpen}
        onClose={() => setPwOpen(false)}
        onSuccess={() => {
          setPwOpen(false);
          setPwSuccess(true);
          setTimeout(() => setPwSuccess(false), 4000);
        }}
      />
      <EditDisplayNameDialog
        open={nameOpen}
        user={user}
        onClose={() => setNameOpen(false)}
        onSuccess={() => {
          setNameOpen(false);
          setNameSuccess(true);
          setTimeout(() => setNameSuccess(false), 4000);
        }}
      />
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-tk-sm">
      <h2 className="text-[11px] font-semibold uppercase tracking-wider text-light-text-hint">
        {title}
      </h2>
      <div className="overflow-hidden rounded-lg border border-light-hairline bg-light-card divide-y divide-light-hairline">
        {children}
      </div>
    </section>
  );
}

interface RowProps {
  icon: ComponentType<SVGProps<SVGSVGElement>>;
  tone: Tone;
  title: string;
  subtitle?: string;
  hint?: string;
  to?: string;
  onClick?: () => void;
  disabled?: boolean;
}

function Row({ icon: Icon, tone, title, subtitle, hint, to, onClick, disabled }: RowProps) {
  const inner = (
    <>
      <span
        className={cn(
          'grid h-9 w-9 shrink-0 place-items-center rounded-md',
          toneBadgeClasses[tone],
        )}
      >
        <Icon className="h-4 w-4" />
      </span>
      <div className="min-w-0 flex-1">
        <div className="text-bodyMedium font-medium text-light-text">{title}</div>
        {subtitle ? (
          <div className="mt-[2px] text-bodySmall text-light-text-secondary">{subtitle}</div>
        ) : null}
      </div>
      {hint ? (
        <span className="text-[12px] text-light-text-hint">{hint}</span>
      ) : disabled ? null : (
        <ChevronRightIcon className="h-4 w-4 shrink-0 text-light-text-hint" />
      )}
    </>
  );

  const cls =
    'flex w-full items-center gap-tk-md p-tk-md text-left transition-colors';
  const enabled = 'hover:bg-light-subtle';
  const dim = 'opacity-60 cursor-not-allowed';

  if (disabled) {
    return <div className={cn(cls, dim)}>{inner}</div>;
  }
  if (to) {
    return (
      <Link to={to} className={cn(cls, enabled)}>
        {inner}
      </Link>
    );
  }
  return (
    <button type="button" onClick={onClick} className={cn(cls, enabled)}>
      {inner}
    </button>
  );
}
