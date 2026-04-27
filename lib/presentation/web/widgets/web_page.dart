import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';

/// Page wrapper used by web admin screens. Renders inside the shell, so
/// screens never build their own [Scaffold] / [AppBar] when wrapped in a
/// [WebPage].
///
/// Layout:
/// ```
/// title row (title + actions)
/// optional subheader (filter / search row)
/// child (the actual page content)
/// ```
class WebPage extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? subheader;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const WebPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.subheader,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.lg,
      AppSpacing.xl,
      AppSpacing.xl,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (actions != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      actions![i],
                    ],
                  ],
                ),
            ],
          ),
          if (subheader != null) ...[
            const SizedBox(height: AppSpacing.md),
            subheader!,
          ],
          const SizedBox(height: AppSpacing.lg),
          Expanded(child: child),
        ],
      ),
    );
  }
}
