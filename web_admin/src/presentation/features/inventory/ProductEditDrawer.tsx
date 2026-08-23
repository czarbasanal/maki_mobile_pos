// Product editing, hosted in the same drawer as the product view rather than
// on a page of its own. Lives at /inventory/:id/edit, so Back steps from edit
// to view instead of closing outright, and an edit link stays shareable.
//
// The form itself is InventoryFormPage in `embedded` mode — the same component
// still serves the full-page "New product" flow, so create and edit can't
// drift apart.
import { generatePath, useNavigate, useParams } from 'react-router-dom';
import { Drawer } from '@/presentation/components/common/Drawer';
import { RoutePaths } from '@/presentation/router/routePaths';
import { useProduct } from '@/presentation/hooks/useProduct';
import { InventoryFormPage } from './InventoryFormPage';

export function ProductEditDrawer() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const { data: product } = useProduct(id);

  const backToView = () =>
    navigate(id ? generatePath(RoutePaths.productDetail, { id }) : RoutePaths.inventory);

  return (
    <Drawer
      open
      onClose={backToView}
      title={product ? product.name : 'Edit product'}
      description="Editing"
    >
      <InventoryFormPage embedded />
    </Drawer>
  );
}
