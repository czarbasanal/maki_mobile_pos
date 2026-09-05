// Role as a tone-coded tag on the shared Badge (users guide §1): Admin amber,
// Staff green, Cashier blue — the same tones the avatar tile and role card use.
import { userRoleDisplayName, type UserRole } from '@/domain/enums';
import { Badge, type Tone } from '@/presentation/components/ui/Badge';

export const roleTone: Record<UserRole, Tone> = {
  admin: 'warning',
  staff: 'positive',
  cashier: 'info',
};

/** Token vars matching roleTone, for the avatar tile and the role card bar. */
export const roleColor: Record<UserRole, { fill: string; soft: string; text: string }> = {
  admin: { fill: 'var(--accent)', soft: 'var(--accent-soft)', text: 'var(--accent-text)' },
  staff: { fill: 'var(--pos)', soft: 'var(--pos-soft)', text: 'var(--pos)' },
  cashier: { fill: 'var(--info)', soft: 'var(--info-soft)', text: 'var(--info)' },
};

export function RoleBadge({ role }: { role: UserRole }) {
  return (
    <Badge tone={roleTone[role]} shape="tag">
      <span className="text-[10.5px] font-semibold uppercase tracking-[0.5px]">{userRoleDisplayName[role]}</span>
    </Badge>
  );
}
