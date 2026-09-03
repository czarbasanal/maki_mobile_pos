import type { Tag } from '../entities';
import type { TagColor } from '@/domain/tags/tagColors';
import type { Unsubscribe } from './AuthRepository';

export interface TagCreateInput {
  name: string;
  color: TagColor;
  description?: string | null;
}

export interface TagUpdateInput {
  name?: string;
  color?: TagColor;
  // null clears the stored value; undefined leaves it untouched.
  description?: string | null;
  isActive?: boolean;
}

export interface TagRepository {
  watchAll(cb: (tags: Tag[]) => void, opts?: { includeInactive?: boolean }): Unsubscribe;
  /** Exact-name existence check (any active state). */
  nameExists(name: string): Promise<boolean>;
  create(input: TagCreateInput, actorId: string): Promise<Tag>;
  update(id: string, input: TagUpdateInput, actorId: string): Promise<void>;
  /** Hard-deletes the tag doc. Orphaned Product.tagIds entries are tolerated
   *  by every reader (unresolvable ids simply don't render). */
  delete(id: string): Promise<void>;
}
