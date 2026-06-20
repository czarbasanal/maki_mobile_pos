import { describe, expect, it } from 'vitest';
import { canAccess } from './routeGuards';
import { RoutePaths } from './routePaths';
import { UserRole } from '@/domain/enums';
import type { User } from '@/domain/entities/User';

const admin: User = {
  id: 'u1',
  email: 'admin@shop.test',
  displayName: 'Admin',
  role: UserRole.admin,
  isActive: true,
  phoneNumber: null,
  photoUrl: null,
  createdAt: new Date('2026-01-01'),
  updatedAt: null,
  createdBy: null,
  updatedBy: null,
  lastLoginAt: null,
};

describe('canAccess — settings routes', () => {
  it('admin can reach the admin-managed list pages', () => {
    // Manage Lists already works; Mechanics is the same manageCategories gate.
    expect(canAccess(RoutePaths.manageLists, admin)).toBe(true);
    expect(canAccess(RoutePaths.mechanics, admin)).toBe(true);
  });
});
