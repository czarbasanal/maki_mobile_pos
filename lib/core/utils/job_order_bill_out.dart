import 'package:maki_mobile_pos/domain/entities/job_order_entity.dart';

/// A Job Order can be billed out only once its motorcycle model is set
/// (decision #5). The billable-content requirement (items, labor, or fees)
/// is enforced separately by [JobOrderEntity.hasBillableContent].
bool jobOrderReadyToBillOut(JobOrderEntity jobOrder) =>
    jobOrder.motorcycleModel?.trim().isNotEmpty ?? false;
