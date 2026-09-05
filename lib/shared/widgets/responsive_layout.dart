import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Supported Android width classes.
///
/// The boundaries correspond to the release QA viewports: 320dp compact,
/// 360dp standard, 600dp tablet, 840dp unfolded/large, and 1280dp maximum.
enum AppWidthClass {
  compact,
  standard,
  tablet,
  large,
}

/// How much detail a chart should show at the current width.
enum ChartLabelDensity {
  /// Show only evenly sampled, short labels.
  sparse,

  /// Prefer abbreviated labels and sample when there are many points.
  abbreviated,

  /// Show labels in full, sampling only unusually dense data sets.
  full,
}

/// Shared responsive constants and calculations for Android layouts.
///
/// Screens should consume these values or the widgets below instead of adding
/// local width breakpoints. Width classification is intentionally stable
/// outside the supported 320–1280dp range so previews and resizing degrade
/// predictably, although those widths are not release targets.
abstract final class ResponsiveStandards {
  static const double minSupportedWidth = 320;
  static const double standardBreakpoint = 360;
  static const double tabletBreakpoint = 600;
  static const double largeBreakpoint = 840;
  static const double maxSupportedWidth = 1280;

  /// Maximum width of the centered page column, including its inner padding.
  static const double maxReadableContentWidth = 840;

  /// Material/Android minimum interactive target in logical pixels.
  static const double minTapTarget = 48;

  /// Default card width used to decide whether a grid can add a column.
  static const double minCardWidth = 240;

  /// Classifies a logical width using half-open ranges.
  ///
  /// Compact is below 360dp, standard is 360–599dp, tablet is 600–839dp,
  /// and large is 840dp and above.
  static AppWidthClass widthClassFor(double width) {
    if (!width.isFinite || width < 0) {
      throw ArgumentError.value(
          width, 'width', 'must be finite and non-negative');
    }
    if (width < standardBreakpoint) return AppWidthClass.compact;
    if (width < tabletBreakpoint) return AppWidthClass.standard;
    if (width < largeBreakpoint) return AppWidthClass.tablet;
    return AppWidthClass.large;
  }

  /// Common page inset for a logical width.
  static double horizontalPaddingFor(double width) {
    return switch (widthClassFor(width)) {
      AppWidthClass.compact => AppSpacing.md,
      AppWidthClass.standard => 20,
      AppWidthClass.tablet => AppSpacing.lg,
      AppWidthClass.large => AppSpacing.xl,
    };
  }

  /// Common card interior inset for a logical screen width.
  static double cardPaddingFor(double width) {
    return switch (widthClassFor(width)) {
      AppWidthClass.compact || AppWidthClass.standard => AppSpacing.md,
      AppWidthClass.tablet || AppWidthClass.large => AppSpacing.lg,
    };
  }

  /// Chooses a readable number of equal-width cards for [availableWidth].
  ///
  /// A single-column list is always returned when another column would make a
  /// card narrower than [minItemWidth]. This is the standard narrow fallback.
  static int adaptiveColumnCount(
    double availableWidth, {
    double minItemWidth = minCardWidth,
    double spacing = AppSpacing.md,
    int maxColumns = 3,
  }) {
    if (!availableWidth.isFinite || availableWidth < 0) {
      throw ArgumentError.value(
        availableWidth,
        'availableWidth',
        'must be finite and non-negative',
      );
    }
    if (minItemWidth <= 0 || !minItemWidth.isFinite) {
      throw ArgumentError.value(
        minItemWidth,
        'minItemWidth',
        'must be finite and greater than zero',
      );
    }
    if (spacing < 0 || !spacing.isFinite) {
      throw ArgumentError.value(
        spacing,
        'spacing',
        'must be finite and non-negative',
      );
    }
    if (maxColumns < 1) {
      throw ArgumentError.value(maxColumns, 'maxColumns', 'must be at least 1');
    }

    final columns =
        ((availableWidth + spacing) / (minItemWidth + spacing)).floor();
    return columns.clamp(1, maxColumns);
  }

  static ChartLabelDensity chartLabelDensityFor(double width) {
    return switch (widthClassFor(width)) {
      AppWidthClass.compact => ChartLabelDensity.sparse,
      AppWidthClass.standard => ChartLabelDensity.abbreviated,
      AppWidthClass.tablet || AppWidthClass.large => ChartLabelDensity.full,
    };
  }

  /// Returns the interval at which chart labels should be rendered.
  ///
  /// Compact charts show at most four short labels, standard charts at most
  /// six abbreviated labels, tablets at most eight full labels, and large
  /// layouts at most twelve. Chart implementations should always retain an
  /// accessible semantic summary of the complete data set.
  static int chartLabelStrideFor(double width, int labelCount) {
    if (labelCount < 0) {
      throw ArgumentError.value(
          labelCount, 'labelCount', 'must not be negative');
    }
    if (labelCount == 0) return 1;

    final maxVisibleLabels = switch (widthClassFor(width)) {
      AppWidthClass.compact => 4,
      AppWidthClass.standard => 6,
      AppWidthClass.tablet => 8,
      AppWidthClass.large => 12,
    };
    return math.max(1, (labelCount / maxVisibleLabels).ceil());
  }
}

/// Centers a page in a readable column and applies the standard horizontal
/// inset for the current width.
class ResponsiveConstrainedPage extends StatelessWidget {
  const ResponsiveConstrainedPage({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveStandards.maxReadableContentWidth,
    this.horizontalPadding,
  });

  final Widget child;
  final double maxWidth;
  final double? horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaWidth = MediaQuery.sizeOf(context).width;
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : mediaWidth;
        final pageWidth = math.min(availableWidth, maxWidth);
        final padding = horizontalPadding ??
            ResponsiveStandards.horizontalPaddingFor(availableWidth);

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: pageWidth,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Renders children as a one-column list or an equal-width wrapping grid.
///
/// This helper deliberately does not scroll. Place it in the page's existing
/// scroll view so the screen retains one scroll owner and dynamic card heights
/// can wrap naturally without a grid aspect-ratio constraint.
class AdaptiveGridList extends StatelessWidget {
  const AdaptiveGridList({
    super.key,
    required this.children,
    this.minItemWidth = ResponsiveStandards.minCardWidth,
    this.maxColumns = 3,
    this.spacing = AppSpacing.md,
    this.runSpacing = AppSpacing.md,
  });

  final List<Widget> children;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = ResponsiveStandards.adaptiveColumnCount(
          availableWidth,
          minItemWidth: minItemWidth,
          spacing: spacing,
          maxColumns: maxColumns,
        );

        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) SizedBox(height: runSpacing),
                children[index],
              ],
            ],
          );
        }

        final itemWidth =
            (availableWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Card with shared responsive interior spacing.
class ResponsiveCard extends StatelessWidget {
  const ResponsiveCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final effectivePadding = padding ??
        EdgeInsets.all(ResponsiveStandards.cardPaddingFor(screenWidth));

    return Card(
      margin: margin,
      clipBehavior: clipBehavior,
      child: Padding(
        padding: effectivePadding,
        child: child,
      ),
    );
  }
}
