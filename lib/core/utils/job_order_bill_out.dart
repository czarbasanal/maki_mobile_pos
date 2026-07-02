import 'package:maki_mobile_pos/domain/entities/draft_entity.dart';

/// A Job Order can be billed out only once its motorcycle model is set
/// (decision #5). The item-count requirement is enforced separately by the
/// checkout flow's existing "items required" rule.
bool jobOrderReadyToBillOut(DraftEntity draft) =>
    draft.motorcycleModel?.trim().isNotEmpty ?? false;
