import { useState } from 'react';
import { TagIcon } from '@heroicons/react/24/outline';
import { Modal } from '@/presentation/components/ui/Modal';
import { useUpdateProductTags } from '@/presentation/hooks/useProductMutations';
import { tagChipStyle } from '@/domain/tags/tagColors';
import { cn } from '@/core/utils/cn';
import type { Product, Tag } from '@/domain/entities';

/** Tag-icon button on an inventory row: opens a small Modal listing every
 *  active tag as a toggle chip — the same chip vocabulary as the product
 *  modal's Tags field, so tagging looks identical wherever it happens. Each
 *  toggle writes immediately (no Save step) — local `ids` state is the
 *  running composed array so successive toggles stack correctly even while
 *  a previous write is still in flight. */
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
          setIds(product.tagIds);
          setOpen(true);
        }}
        className="flex h-6 w-6 shrink-0 items-center justify-center rounded-[6px] text-ink-3 hover:bg-surface-3 hover:text-ink-2"
      >
        <TagIcon className="h-3.5 w-3.5" />
      </button>
      <Modal
        open={open}
        onClose={() => setOpen(false)}
        title={product.name}
        subtitle="Tap a tag to attach or remove it — changes save immediately."
        icon={
          <div
            aria-hidden
            className="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[10px] bg-accent-soft text-accent-text"
          >
            <TagIcon className="h-[18px] w-[18px]" />
          </div>
        }
        size="sm"
        initialFocus="none"
      >
        {tags.length === 0 ? (
          <p className="text-ctl-sm text-ink-2">
            No tags yet — create tags in Settings → Product tags.
          </p>
        ) : (
          <div className="flex flex-wrap gap-1.5">
            {tags.map((t) => {
              const selected = ids.includes(t.id);
              const s = tagChipStyle(t.color);
              return (
                <button
                  key={t.id}
                  type="button"
                  aria-pressed={selected}
                  onClick={() => toggle(t.id)}
                  className={cn(
                    'rounded-[6px] border px-2 py-[3px] text-[11px] font-medium',
                    selected ? 'border-transparent' : 'border-line bg-surface text-ink-3',
                  )}
                  style={selected ? { background: s.bg, color: s.fg } : undefined}
                >
                  {t.name}
                </button>
              );
            })}
          </div>
        )}
      </Modal>
    </>
  );
}
