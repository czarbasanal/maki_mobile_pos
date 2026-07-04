import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/app_card.dart';

/// A single pulsing placeholder bar/box used to build skeleton screens while
/// data is being fetched. Pulses opacity (Airbnb-style) rather than a sweeping
/// shimmer — cheaper and matches the calm, airy theme.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0x14FFFFFF) : const Color(0x0F111C1D);
    final tween = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    return FadeTransition(
      opacity: tween,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A skeleton list: [count] placeholder rows shaped like the app's list cards
/// (a leading square + two text bars), shown while a list is loading.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: count,
      itemBuilder: (context, _) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm + 4),
        child: _SkeletonRow(),
      ),
    );
  }
}

/// A single field-shaped skeleton — placeholder for a text field / dropdown
/// while its data source loads. Replaces bare LinearProgressIndicators.
class FieldSkeleton extends StatelessWidget {
  const FieldSkeleton({super.key, this.height = 56});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: double.infinity,
      height: height,
      radius: AppRadius.field,
    );
  }
}

/// Skeleton for a form screen while its record loads: [fields] field-shaped
/// bars + a button-shaped bar, inside the standard page padding.
class FormSkeleton extends StatelessWidget {
  const FormSkeleton({super.key, this.fields = 6});

  final int fields;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (var i = 0; i < fields; i++) ...[
          const FieldSkeleton(),
          const SizedBox(height: AppSpacing.md),
        ],
        const SizedBox(height: AppSpacing.md),
        const FieldSkeleton(height: 52),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppRadius.field,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const SkeletonBox(width: 40, height: 40, radius: 11),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 160, height: 13),
                SizedBox(height: 8),
                SkeletonBox(width: 100, height: 11),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const SkeletonBox(width: 48, height: 16),
        ],
      ),
    );
  }
}
