import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';

/// A reusable section header widget that renders a left-aligned title
/// and an optional right-aligned trailing label in uppercase monospaced style.
///
/// Used throughout the dashboard to label sections like "CALENDAR GRID",
/// "WEEKLY LOAD", and "COMPLETED SESSIONS".
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailingLabel,
  });

  /// The section title displayed on the left (rendered uppercase).
  final String title;

  /// An optional label displayed on the right at reduced opacity.
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
