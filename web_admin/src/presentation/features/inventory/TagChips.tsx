import type { Tag } from '@/domain/entities';
import { tagChipStyle } from '@/domain/tags/tagColors';

/** Resolved tag chips for one product row: first `max` + a "+n" overflow.
 *  Unresolvable ids (deleted tags) and inactive tags simply don't render —
 *  callers pass the ACTIVE tag list. */
export function TagChips({ tagIds, tags, max = 2 }: { tagIds: string[]; tags: Tag[]; max?: number }) {
  const byId = new Map(tags.map((t) => [t.id, t]));
  const resolved = tagIds.map((id) => byId.get(id)).filter((t): t is Tag => !!t);
  if (resolved.length === 0) return null;
  const shown = resolved.slice(0, max);
  const extra = resolved.length - shown.length;
  return (
    <span className="flex flex-wrap items-center gap-1">
      {shown.map((t) => {
        const s = tagChipStyle(t.color);
        return (
          <span
            key={t.id}
            className="whitespace-nowrap rounded-[6px] px-2 py-[3px] text-[11px] font-medium"
            style={{ background: s.bg, color: s.fg }}
          >
            {t.name}
          </span>
        );
      })}
      {extra > 0 ? (
        <span className="whitespace-nowrap rounded-[6px] bg-surface-3 px-1.5 py-[3px] text-[11px] font-medium text-ink-2">
          +{extra}
        </span>
      ) : null}
    </span>
  );
}
