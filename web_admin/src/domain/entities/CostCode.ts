// Mirror of lib/domain/entities/cost_code_entity.dart. Encodes prices as
// letters. Default mapping (1-9 → A-I, 0 → J) plus special codes for double
// (SC) and triple (SCS) zeros.

export interface CostCode {
  digitToLetter: Record<string, string>;
  doubleZeroCode: string;
  tripleZeroCode: string;
  updatedAt: Date | null;
  updatedBy: string | null;
}

export const defaultCostCode: CostCode = {
  digitToLetter: {
    '1': 'A',
    '2': 'B',
    '3': 'C',
    '4': 'D',
    '5': 'E',
    '6': 'F',
    '7': 'G',
    '8': 'H',
    '9': 'I',
    '0': 'J',
  },
  doubleZeroCode: 'SC',
  tripleZeroCode: 'SCS',
  updatedAt: null,
  updatedBy: null,
};
