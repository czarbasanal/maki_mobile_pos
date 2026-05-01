// /admin/settings — settings overview. Mirrors the Flutter settings_screen
// structure: profile section + admin section + general section.
//
// Display-name editing is deferred to phase 4 (when UserRepository writes
// land). For phase 3 the profile is read-only with a working change-password
// flow via FirebaseAuthRepository.

import { useEffect, useState, type ComponentType, type SVGProps } from 'react';
import { Link } from 'react-router-dom';
import {
  ChevronRightIcon,
  ClockIcon,
  CodeBracketSquareIcon,
  InformationCircleIcon,
  KeyIcon,
  UserIcon,
  UsersIcon,
} from '@heroicons/react/24/outline';
import { useAuthStore } from '@/presentation/stores/authStore';
import { RoutePaths } from '@/presentation/router/routePaths';
import { ChangePasswordDialog } from './ChangePasswordDialog';
import { userRoleDisplayName } from '@/domain/enums';
import { toneBadgeClasses, type Tone } from '@/core/theme/tones';
import { cn } from '@/core/utils/cn';

export function SettingsPage() {
  const user = useAuthStore((s) => s.user);
  const [pwOpen, setPwOpen] = useState(false);
  const [pwSuccess, setPwSuccess] = useState(false);

  useEffect(() => {
    document.title = 'Settings · MAKI POS Admin';
  }, []);

  if (!user) return null;

  return (
    <div className="space-y-tk-xl px-tk-xl py-tk-lg">
      <header>
        <h1 className="text-headingMedium font-semibold tracking-tight text-light-text">
          Settings
        </h1>
        <p className="mt-tk-xs text-bodySmall text-light-text-secondary">
          Account, administration, and app information.
        </p>
      </header>

      {pwSuccess ? (
        <div className="rounded-md border border-success-light bg-success-light/40 px-tk-md py-tk-sm text-bodySmall text-success-dark">
          Password updated.
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
          hint="Editable in phase 4"
          disabled
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
        <Row
          to={RoutePaths.users}
          icon={UsersIcon}
          tone="blue"
          title="User management"
          subtitle="Add, edit, and manage users"
        />
        <Row
          to={RoutePaths.userLogs}
          icon={ClockIcon}
          tone="violet"
          title="Activity logs"
          subtitle="View user activity and audit trail"
        />
        <Row
          to={RoutePaths.costCodeSettings}
          icon={CodeBracketSquareIcon}
          tone="orange"
          title="Cost code settings"
          subtitle="Configure cost encoding"
        />
      </Section>

      <Section title="General">
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
