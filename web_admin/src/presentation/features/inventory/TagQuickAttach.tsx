import { useState } from 'react';
import { TagIcon } from '@heroicons/react/24/outline';
import { Dialog } from '@/presentation/components/common/Dialog';
import { useUpdateProductTags } from '@/presentation/hooks/useProductMutations';
import { tagChipStyle } from '@/domain/tags/tagColors';
import type { Product, Tag } from '@/domain/entities';

/** Tag-icon button on an inventory row: opens a small Dialog listing every
 *  active tag as a toggle checkbox. Each toggle writes immediately (no Save
 *  step) — local `ids` state is the running composed array so successive
 *  toggles stack correctly even while a previous write is still in flight. */
export function TagQuickAttachButton({ product, tags }: { product: Product; tags: Tag[] }) {
  const [open, setOpen] = useState(false);
  const [ids, setIds] = useState<string[]>(product.tagIds);
  const update = useUpdateProductTags();

  const toggle = (tagId: string) => {
    const next = ids.includes(tagId) ? ids.filter((id) => id !== tagId) : [...ids, tagId];
    setIds(next);
    update.mutate({ id: product.id, name: product.name, tagIds: next });
  };

  return (
    <>
      <button
        type="button"
        aria-label="Edit tags"
        onClick={(e) => {
          e.stopPropagation();
          setOpen(true);
        }}
        className="flex h-6 w-6 shrink-0 items-center justify-center rounded-[6px] text-ink-3 hover:bg-surface-3 hover:text-ink-2"
      >
        <TagIcon className="h-3.5 w-3.5" />
      </button>
      <Dialog open={open} onClose={() => setOpen(false)} title={product.name} className="max-w-sm">
        {tags.length === 0 ? (
          <p className="text-ctl-sm text-ink-2">
            No tags yet — create tags in Settings → Product tags.
          </p>
        ) : (
          <div className="flex flex-col gap-1">
            {tags.map((t) => (
              <label
                key={t.id}
                className="flex items-center gap-2 rounded-[6px] px-1.5 py-1 text-ctl-sm text-ink hover:bg-surface-2"
              >
                <input type="checkbox" checked={ids.includes(t.id)} onChange={() => toggle(t.id)} />
                <span
                  aria-hidden="true"
                  className="h-2 w-2 shrink-0 rounded-full"
                  style={{ background: tagChipStyle(t.color).fg }}
                />
                {t.name}
              </label>
            ))}
          </div>
        )}
      </Dialog>
    </>
  );
}
