// Add/edit supplier as a MODAL over the directory (same pattern as the
// inventory Add-product modal): routed at /suppliers/add and
// /suppliers/edit/:id as children of the list — deep links and the
// addSupplier guard keep working — hosting SupplierFormPage in embedded
// mode. The form navigates back to /suppliers after save/cancel/deactivate,
// which unmounts the route and closes the modal.
import { useNavigate, useParams } from 'react-router-dom';
import { Dialog } from '@/presentation/components/common/Dialog';
import { RoutePaths } from '@/presentation/router/routePaths';
import { SupplierFormPage } from './SupplierFormPage';

export function SupplierModal() {
  const navigate = useNavigate();
  const { id } = useParams<{ id: string }>();
  return (
    <Dialog
      open
      onClose={() => navigate(RoutePaths.suppliers)}
      title={id ? 'Edit supplier' : 'New supplier'}
      className="max-w-xl"
    >
      <div className="max-h-[75vh] overflow-y-auto pr-tk-xs">
        <SupplierFormPage embedded />
      </div>
    </Dialog>
  );
}
