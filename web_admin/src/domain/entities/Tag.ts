import type { TagColor } from '@/domain/tags/tagColors';

// Mirror of lib/domain/entities/tag_entity.dart. Custom product tags in the
// shared `product_tags` collection; attached to products via Product.tagIds.
// Built for the physical-count sweep (spec 2026-09-03) but general-purpose.
export interface Tag {
  id: string;
  name: string;          // display + match key
  color: TagColor;       // named token; each surface maps it to its own tint
  description: string | null; // shown only in the tag editor, never on rows
  isActive: boolean;     // soft-delete; inactive chips disappear, ids stay on products
  createdAt: Date;
  updatedAt: Date | null;
  createdBy: string | null;
  updatedBy: string | null;
}
