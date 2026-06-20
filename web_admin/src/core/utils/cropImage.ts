const OUTPUT_SIZE = 1024;
const JPEG_QUALITY = 0.82;

export interface PixelArea {
  x: number;
  y: number;
  width: number;
  height: number;
}

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.addEventListener('load', () => resolve(img));
    img.addEventListener('error', () => reject(new Error('Could not load the image')));
    img.src = src;
  });
}

/**
 * Draws the cropped `area` of `imageSrc` onto a square OUTPUT_SIZE canvas and
 * returns a compressed JPEG blob (well under the 2 MB Storage limit). `area` is
 * react-easy-crop's `croppedAreaPixels`.
 */
export async function getCroppedBlob(imageSrc: string, area: PixelArea): Promise<Blob> {
  const image = await loadImage(imageSrc);
  const canvas = document.createElement('canvas');
  canvas.width = OUTPUT_SIZE;
  canvas.height = OUTPUT_SIZE;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('Canvas is not supported');
  ctx.drawImage(image, area.x, area.y, area.width, area.height, 0, 0, OUTPUT_SIZE, OUTPUT_SIZE);
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error('Could not encode the image'))),
      'image/jpeg',
      JPEG_QUALITY,
    );
  });
}
