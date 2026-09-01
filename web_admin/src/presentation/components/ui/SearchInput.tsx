import { useEffect, useRef, useState, type KeyboardEvent, type RefObject } from 'react';
import { clsx } from 'clsx';
import { MagnifyingGlassIcon, XMarkIcon } from '@heroicons/react/24/outline';

export interface SearchInputProps {
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  debounce?: number;
  /** 'hero' is the POS register treatment: surface card, 12px radius,
   *  shadow, 14px input — the primary target on its screen. */
  variant?: 'field' | 'hero';
  autoFocus?: boolean;
  /** Keyboard events from the inner input (register keyboard map). The
   *  second argument is the LIVE text — a wedge scanner sends Enter faster
   *  than the debounce, so Enter handlers must never read debounced state. */
  onKeyDown?: (e: KeyboardEvent<HTMLInputElement>, currentText: string) => void;
  /** Escape hatch for programmatic focus (e.g. refocus after a sale). */
  inputRef?: RefObject<HTMLInputElement>;
}

export function SearchInput({
  value,
  onChange,
  placeholder = 'Search',
  debounce = 250,
  variant = 'field',
  autoFocus = false,
  onKeyDown,
  inputRef,
}: SearchInputProps) {
  const [text, setText] = useState(value);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (timer.current) clearTimeout(timer.current);
    setText(value);
  }, [value]);
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

  const hero = variant === 'hero';
  return (
    <div
      className={clsx(
        'flex items-center',
        hero
          ? 'gap-2.5 rounded-[12px] border border-line bg-surface px-[15px] py-3 shadow-card'
          : 'gap-1.5 rounded-field border border-line bg-surface-2 px-2.5 py-1.5',
      )}
    >
      <MagnifyingGlassIcon className={clsx('shrink-0 text-ink-3', hero ? 'h-4 w-4' : 'h-3.5 w-3.5')} />
      <input
        ref={inputRef}
        value={text}
        autoFocus={autoFocus}
        onChange={(e) => handleInput(e.target.value)}
        onKeyDown={onKeyDown ? (e) => onKeyDown(e, text) : undefined}
        placeholder={placeholder}
        className={clsx(
          'bg-transparent text-ink outline-none placeholder:text-ink-3',
          hero ? 'w-full text-ctl-lg' : 'w-40 text-ctl-sm',
        )}
      />
      {text && (
        <button type="button" aria-label="Clear search" onClick={handleClear} className="text-ink-3 hover:text-ink-2">
          <XMarkIcon className={hero ? 'h-4 w-4' : 'h-3.5 w-3.5'} />
        </button>
      )}
    </div>
  );
}
