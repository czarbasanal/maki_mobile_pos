// A product's photo, or a consistent placeholder when it has none.
//
// Single source for the "no image yet" state. Most of the catalogue was bulk
// imported without photos, so the empty case is the common one — rendering an
// <img> with an empty src would show the browser's broken-image glyph on most
// rows, which reads as an error rather than "not added yet".
import { PhotoIcon } from '@heroicons/react/24/outline';
import { cn } from '@/core/utils/cn';

const SIZES = {
  sm: 'h-10 w-10',
  md: 'h-16 w-16',
  lg: 'h-32 w-32',
} as const;

const ICON_SIZES = {
  sm: 'h-4 w-4',
  md: 'h-6 w-6',
  lg: 'h-10 w-10',
} as const;

interface ProductImageProps {
  /** `null` or `''` both mean "no photo" — see the note above. */
  src: string | null | undefined;
  /** Describes the product, not the picture — usually the product name. */
  alt: string;
  size?: keyof typeof SIZES;
  className?: string;
}

export function ProductImage({ src, alt, size = 'sm', className }: ProductImageProps) {
  const box = cn(
    SIZES[size],
    'shrink-0 overflow-hidden rounded-md border border-light-hairline',
    className,
  );

  if (!src) {
    return (
      <div
        className={cn(box, 'flex items-center justify-center bg-light-subtle')}
        aria-label="No image"
        role="img"
      >
        <PhotoIcon className={cn(ICON_SIZES[size], 'text-light-text-hint')} aria-hidden="true" />
      </div>
    );
  }

  return (
    <div className={box}>
      <img src={src} alt={alt} className="h-full w-full object-cover" />
    </div>
  );
}
