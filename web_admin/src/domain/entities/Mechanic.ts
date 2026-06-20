// Mirror of lib/domain/entities/mechanic_entity.dart. Admin-managed list of
// mechanics in the shared `mechanics` collection; assigned (optionally) to a
// service sale.
export interface Mechanic {
  id: string;
  name: string;        // display + match key
  isActive: boolean;   // soft-delete; inactive drops off the picker, stays valid on history
  createdAt: Date;
  updatedAt: Date | null;
  createdBy: string | null;
  updatedBy: string | null;
}
