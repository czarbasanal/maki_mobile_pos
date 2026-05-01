// Mirror of lib/domain/entities/petty_cash_entity.dart.
export const PettyCashType = {
  cashIn: 'cashIn',
  cashOut: 'cashOut',
  cutOff: 'cutOff',
} as const;

export type PettyCashType = (typeof PettyCashType)[keyof typeof PettyCashType];

export interface PettyCash {
  id: string;
  type: PettyCashType;
  amount: number;
  balance: number;
  description: string;
  referenceId: string | null;
  createdAt: Date;
  createdBy: string;
  createdByName: string;
  notes: string | null;
}
