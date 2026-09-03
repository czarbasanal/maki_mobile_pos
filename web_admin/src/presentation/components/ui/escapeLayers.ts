// One Escape, one layer (supplier-modal guide §2): overlays register on a
// module-level stack and a single capture-phase document listener closes
// ONLY the topmost — a dropdown inside a modal consumes the first press,
// the modal the second, never both at once.
import { useEffect, useRef } from 'react';

type Layer = { onEscape: () => void };
const stack: Layer[] = [];
let listening = false;

function onKeyDown(e: KeyboardEvent) {
  if (e.key !== 'Escape' || stack.length === 0) return;
  e.stopPropagation();
  stack[stack.length - 1].onEscape();
}

function ensureListener() {
  if (listening) return;
  listening = true;
  document.addEventListener('keydown', onKeyDown, true);
}

/** Registers `onEscape` as the top escape layer while `active`. */
export function useEscapeLayer(active: boolean, onEscape: () => void) {
  const handler = useRef(onEscape);
  handler.current = onEscape;
  useEffect(() => {
    if (!active) return;
    ensureListener();
    const layer: Layer = { onEscape: () => handler.current() };
    stack.push(layer);
    return () => {
      const i = stack.indexOf(layer);
      if (i !== -1) stack.splice(i, 1);
    };
  }, [active]);
}
