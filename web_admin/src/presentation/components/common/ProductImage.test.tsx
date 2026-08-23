// One component for every place a product's photo appears (inventory list,
// product drawer, edit form) so the "no image yet" state looks the same
// everywhere instead of each screen inventing its own empty box.
import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ProductImage } from './ProductImage';

describe('ProductImage', () => {
  it('shows the photo when the product has one', () => {
    render(<ProductImage src="https://example.test/brake.jpg" alt="Brake shoe" />);

    const img = screen.getByRole('img', { name: 'Brake shoe' });
    expect(img).toHaveAttribute('src', 'https://example.test/brake.jpg');
  });

  it('shows a placeholder instead of a broken image when there is no photo', () => {
    render(<ProductImage src={null} alt="Brake shoe" />);

    // No <img> at all — an empty src would render as a broken-image icon.
    expect(screen.queryByRole('img', { name: 'Brake shoe' })).toBeNull();
    expect(screen.getByLabelText('No image')).toBeInTheDocument();
  });

  it('treats an empty string like no photo at all', () => {
    // Firestore docs written before the field existed can carry '' rather
    // than null; both mean "nothing to show".
    render(<ProductImage src="" alt="Brake shoe" />);

    expect(screen.getByLabelText('No image')).toBeInTheDocument();
  });

  it('renders at the requested size', () => {
    const { container } = render(
      <ProductImage src={null} alt="Brake shoe" size="lg" />,
    );

    expect(container.firstChild).toHaveClass('h-32', 'w-32');
  });

  it('defaults to the small size used by the inventory list', () => {
    const { container } = render(<ProductImage src={null} alt="Brake shoe" />);

    expect(container.firstChild).toHaveClass('h-10', 'w-10');
  });
});
