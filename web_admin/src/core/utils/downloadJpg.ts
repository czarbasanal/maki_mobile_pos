import html2canvas from 'html2canvas';

/**
 * html2canvas places text baselines from its own font measurement, not the
 * browser's line-box model, so some text renders a pixel or two lower in the
 * export than in the live preview. Elements may declare a clone-only
 * correction via `data-export-shift-y="<px>"` — applied ONLY to the cloned
 * document html2canvas rasterizes, never to what the user sees on screen.
 * Values are calibrated against a headless harness (Chromium + WebKit).
 */
function applyExportShifts(doc: Document): void {
  doc.querySelectorAll<HTMLElement>('[data-export-shift-y]').forEach((el) => {
    el.style.position = 'relative';
    el.style.top = `${el.dataset.exportShiftY}px`;
  });
}

export async function downloadElementAsJpg(el: HTMLElement, filename: string): Promise<void> {
  const canvas = await html2canvas(el, {
    backgroundColor: '#ffffff',
    scale: 2,
    onclone: applyExportShifts,
  });
  const a = document.createElement('a');
  a.href = canvas.toDataURL('image/jpeg', 0.92);
  a.download = filename;
  a.click();
}
