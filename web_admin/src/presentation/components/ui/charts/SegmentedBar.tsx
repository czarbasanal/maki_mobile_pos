export interface Segment {
  label: string;
  value: number;
  color: 'pos' | 'accent' | 'neg' | 'surface-3';
}

const colorCls: Record<Segment['color'], string> = {
  pos: 'bg-pos',
  accent: 'bg-accent',
  neg: 'bg-neg',
  'surface-3': 'bg-surface-3',
};

export function SegmentedBar({ segments }: { segments: Segment[] }) {
  const visible = segments.filter((s) => s.value > 0);
  if (visible.length === 0) return <div className="h-2.5 rounded bg-surface-3" />;
  return (
    <div className="flex h-2.5 gap-[2px]">
      {visible.map((segment) => (
        <div
          key={segment.label}
          data-segment
          title={segment.label}
          className={`min-w-[6px] rounded ${colorCls[segment.color]}`}
          style={{ flexGrow: segment.value }}
        />
      ))}
    </div>
  );
}
