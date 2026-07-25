import 'package:maki_mobile_pos/domain/entities/draft_entity.dart';

/// A Job Order can be billed out only once its motorcycle model is set
/// (decision #5). The billable-content requirement (items, labor, or fees)
/// is enforced separately by [DraftEntity.hasBillableContent].
bool jobOrderReadyToBillOut(DraftEntity draft) =>
    draft.motorcycleModel?.trim().isNotEmpty ?? false;
