import { useEffect, useRef, useState } from 'react';
import { MagnifyingGlassIcon, XMarkIcon } from '@heroicons/react/24/outline';

export interface SearchInputProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  debounce?: number;
}

export function SearchInput({ value, onChange, placeholder = 'Search', debounce = 250 }: SearchInputProps) {
  const [text, setText] = useState(value);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => setText(value), [value]);
  useEffect(() => () => { if (timer.current) clearTimeout(timer.current); }, []);

  function handleInput(next: string) {
    setText(next);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => onChange(next), debounce);
  }

  function handleClear() {
    if (timer.current) clearTimeout(timer.current);
    setText('');
    onChange('');
  }

  return (
    <div className="flex items-center gap-1.5 rounded-field border border-line bg-surface-2 px-2.5 py-1.5">
      <MagnifyingGlassIcon className="h-3.5 w-3.5 shrink-0 text-ink-3" />
      <input
        value={text}
        onChange={(e) => handleInput(e.target.value)}
        placeholder={placeholder}
        className="w-40 bg-transparent text-ctl-sm text-ink outline-none placeholder:text-ink-3"
      />
      {text && (
        <button type="button" aria-label="Clear search" onClick={handleClear} className="text-ink-3 hover:text-ink-2">
          <XMarkIcon className="h-3.5 w-3.5" />
        </button>
      )}
    </div>
  );
}
