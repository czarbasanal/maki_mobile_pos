// Tonal pill for the user role. Same hue as the role's UserRole color in the
// Flutter app (admin -> violet, staff -> green, cashier -> blue) routed
// through our shared tonal palette.

import { UserRole, userRoleDisplayName } from '@/domain/enums';
import { toneBadgeClasses, type Tone } from '@/core/theme/tones';

const tones: Record<UserRole, Tone> = {
  admin: 'violet',
  staff: 'green',
  cashier: 'blue',
};

export function RoleBadge({ role }: { role: UserRole }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-tk-sm py-[1px] text-[11px] font-semibold uppercase tracking-wider ${toneBadgeClasses[tones[role]]}`}
    >
      {userRoleDisplayName[role]}
    </span>
  );
}
