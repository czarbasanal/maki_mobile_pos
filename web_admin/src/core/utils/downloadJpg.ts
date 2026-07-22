import html2canvas from 'html2canvas';

export async function downloadElementAsJpg(el: HTMLElement, filename: string): Promise<void> {
  const canvas = await html2canvas(el, { backgroundColor: '#ffffff', scale: 2 });
  const a = document.createElement('a');
  a.href = canvas.toDataURL('image/jpeg', 0.92);
  a.download = filename;
  a.click();
}
