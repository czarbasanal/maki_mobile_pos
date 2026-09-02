// New product as a MODAL over the inventory list (was a separate page).
// Routed at /inventory/add as a child of the list — deep links and the
// addProduct route guard keep working — and the form itself is
// InventoryFormPage in `embedded` mode, the same component the edit drawer
// uses, so create and edit can't drift apart. The form navigates back to
// /inventory after save/cancel, which unmounts this route and closes the
// modal.
import { useNavigate } from 'react-router-dom';
import { Dialog } from '@/presentation/components/common/Dialog';
import { RoutePaths } from '@/presentation/router/routePaths';
import { InventoryFormPage } from './InventoryFormPage';

export function AddProductModal() {
  const navigate = useNavigate();
  return (
    <Dialog
      open
      onClose={() => navigate(RoutePaths.inventory)}
      title="New product"
      description="Set a cost and a price and the register handles the rest."
      className="max-w-2xl"
    >
      <div className="max-h-[75vh] overflow-y-auto pr-tk-xs">
        <InventoryFormPage embedded />
      </div>
    </Dialog>
  );
}
