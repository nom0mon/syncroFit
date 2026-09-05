import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';

/// A reusable section header that intentionally wraps its trailing label when
/// compact width or enlarged text cannot keep both labels readable in one row.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailingLabel,
  });

  final String title;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Text(
          title.toUpperCase(),
          style: AppTextStyles.sectionHeader.copyWith(color: color),
        ),
        if (trailingLabel != null)
          Opacity(
            opacity: 0.5,
            child: Text(
              trailingLabel!.toUpperCase(),
              style: AppTextStyles.sectionHeader.copyWith(color: color),
            ),
          ),
      ],
    );
  }
}
