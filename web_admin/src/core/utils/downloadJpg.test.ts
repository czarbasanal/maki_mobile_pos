import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';

const toDataURL = vi.fn(() => 'data:image/jpeg;base64,stub');
const html2canvasMock = vi.fn(async (..._args: unknown[]) => ({ toDataURL }) as unknown as HTMLCanvasElement);

vi.mock('html2canvas', () => ({
  default: (...args: unknown[]) => html2canvasMock(...args),
}));

import { downloadElementAsJpg } from './downloadJpg';

describe('downloadElementAsJpg', () => {
  let clickSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    toDataURL.mockClear();
    html2canvasMock.mockClear();
    // jsdom attempts a real navigation on `a.click()` for data: hrefs; stub
    // it out so tests assert on call args instead of triggering it.
    clickSpy = vi.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});
  });

  afterEach(() => {
    clickSpy.mockRestore();
  });

  it('renders the element with a white background at 2x scale', async () => {
    const el = document.createElement('div');

    await downloadElementAsJpg(el, 'payslip-juan-dela-cruz-2026-07-20.jpg');

    expect(html2canvasMock).toHaveBeenCalledWith(el, {
      backgroundColor: '#ffffff',
      scale: 2,
      onclone: expect.any(Function),
    });
  });

  it('encodes the canvas as a JPEG at 0.92 quality', async () => {
    const el = document.createElement('div');

    await downloadElementAsJpg(el, 'payslip-juan-dela-cruz-2026-07-20.jpg');

    expect(toDataURL).toHaveBeenCalledWith('image/jpeg', 0.92);
  });

  it('triggers an anchor download with the given filename', async () => {
    const el = document.createElement('div');
    const createElementSpy = vi.spyOn(document, 'createElement');

    await downloadElementAsJpg(el, 'payslip-juan-dela-cruz-2026-07-20.jpg');

    const anchorCall = createElementSpy.mock.results.find(
      (r) => r.value instanceof HTMLAnchorElement,
    );
    const anchor = anchorCall?.value as HTMLAnchorElement;
    expect(anchor.download).toBe('payslip-juan-dela-cruz-2026-07-20.jpg');
    expect(anchor.href).toBe('data:image/jpeg;base64,stub');
  });

  it('clicks the anchor to start the download', async () => {
    const el = document.createElement('div');

    await downloadElementAsJpg(el, 'payslip-juan-dela-cruz-2026-07-20.jpg');

    expect(clickSpy).toHaveBeenCalledTimes(1);
  });
});

describe('export-only shift correction', () => {
  it('the onclone hook lifts marked elements in the clone only', async () => {
    const host = document.createElement('div');
    host.innerHTML = '<span data-export-shift-y="-1">NET PAY</span>';
    document.body.appendChild(host);

    await downloadElementAsJpg(host, 'x.jpg');
    const options = html2canvasMock.mock.calls.at(-1)?.[1] as {
      onclone: (doc: Document) => void;
    };
    expect(options.onclone).toBeTypeOf('function');

    // Run the hook against the live document as a stand-in for the clone.
    options.onclone(document);
    const span = host.querySelector('span') as HTMLElement;
    expect(span.style.position).toBe('relative');
    expect(span.style.top).toBe('-1px');
    host.remove();
  });
});
