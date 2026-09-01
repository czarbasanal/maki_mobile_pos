import html2canvas from 'html2canvas';

/**
 * html2canvas measures font baselines by appending a hidden probe — sample
 * text plus a 1×1 <img> — to the document and reading the img's offsetTop
 * (see html2canvas/dist/lib/render/font-metrics.js). Tailwind preflight's
 * `img { display: block }` knocks that probe img out of the text line, so
 * EVERY glyph in the export drifts several px below where the browser
 * paints it. While rendering, restore inline display for exactly the
 * probe's shape (width="1" height="1" attributes) — no real image matches.
 */
const PROBE_FIX_CSS = 'img[width="1"][height="1"] { display: inline !important; }';

/**
 * Residual sub-pixel corrections: elements may declare a clone-only shift
 * via `data-export-shift-y="<px>"` — applied ONLY to the cloned document
 * html2canvas rasterizes, never to what the user sees on screen. Values
 * are calibrated against a headless harness (Chromium + WebKit).
 */
export function applyExportShifts(doc: Document): void {
  doc.querySelectorAll<HTMLElement>('[data-export-shift-y]').forEach((el) => {
    el.style.position = 'relative';
    el.style.top = `${el.dataset.exportShiftY}px`;
  });
}

/** Rasterize an element exactly as previewed (probe fix + clone shifts). */
export async function renderElementToCanvas(el: HTMLElement): Promise<HTMLCanvasElement> {
  const probeFix = document.createElement('style');
  probeFix.textContent = PROBE_FIX_CSS;
  document.head.appendChild(probeFix);
  try {
    return await html2canvas(el, {
      backgroundColor: '#ffffff',
      scale: 2,
      onclone: applyExportShifts,
    });
  } finally {
    probeFix.remove();
  }
}

export async function downloadElementAsJpg(el: HTMLElement, filename: string): Promise<void> {
  const canvas = await renderElementToCanvas(el);
  const a = document.createElement('a');
  a.href = canvas.toDataURL('image/jpeg', 0.92);
  a.download = filename;
  a.click();
}
