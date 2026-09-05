import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'responsive_layout.dart';

/// A cutout-safe, keyboard-reachable form body with predictable focus order.
///
/// Use this as the body of a [Scaffold] whose `resizeToAvoidBottomInset` is
/// enabled (the default). Short forms keep [bottomAction] at the bottom of the
/// available space; long forms and keyboard-open forms can scroll to it.
class SafeScrollableForm extends StatelessWidget {
  const SafeScrollableForm({
    super.key,
    required this.child,
    this.bottomAction,
    this.controller,
    this.verticalPadding = AppSpacing.md,
    this.horizontalPadding,
    this.bottomActionSpacing = AppSpacing.lg,
    this.includeKeyboardInset = false,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
  });

  final Widget child;
  final Widget? bottomAction;
  final ScrollController? controller;
  final double verticalPadding;
  final double? horizontalPadding;
  final double bottomActionSpacing;

  /// Adds the raw keyboard inset to the scrollable padding.
  ///
  /// Leave this false when a surrounding [Scaffold] resizes its body. Enable
  /// it when embedding the form in a non-resizing overlay.
  final bool includeKeyboardInset;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) {
    final keyboardInset =
        includeKeyboardInset ? MediaQuery.viewInsetsOf(context).bottom : 0.0;

    return SafeArea(
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minimumContentHeight = math.max(
              0.0,
              constraints.maxHeight - (verticalPadding * 2) - keyboardInset,
            );

            return SingleChildScrollView(
              controller: controller,
              keyboardDismissBehavior: keyboardDismissBehavior,
              padding: EdgeInsets.only(
                top: verticalPadding,
                bottom: verticalPadding + keyboardInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minimumContentHeight,
                ),
                child: ResponsiveConstrainedPage(
                  horizontalPadding: horizontalPadding,
                  // The content column takes its natural height and the scroll
                  // view absorbs any overflow, instead of being force-fit into
                  // the min-height box. The previous IntrinsicHeight + Spacer
                  // layout mis-measured content containing TextField character
                  // counters, reporting a height ~20px shorter than the real
                  // layout and squeezing the column into a bottom overflow.
                  //
                  // The ConstrainedBox min-height still keeps short forms
                  // filling the viewport, and [bottomAction] follows the content
                  // with its standard spacing; when the content is taller than
                  // the viewport the column keeps its natural height and scrolls.
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      child,
                      if (bottomAction != null) ...[
                        SizedBox(height: bottomActionSpacing),
                        bottomAction!,
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Animates [child] above the software keyboard.
///
/// This is intended for overlays and non-resizing scaffold regions. Do not
/// combine it with another widget that already consumes `viewInsets.bottom`.
class KeyboardInsetPadding extends StatelessWidget {
  const KeyboardInsetPadding({
    super.key,
    required this.child,
    this.additionalBottomPadding = 0,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOut,
  });

  final Widget child;
  final double additionalBottomPadding;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: duration,
      curve: curve,
      padding: EdgeInsets.only(
        bottom:
            MediaQuery.viewInsetsOf(context).bottom + additionalBottomPadding,
      ),
      child: child,
    );
  }
}

/// A cutout-safe bottom action region that can remain above the keyboard.
class SafeBottomActionBar extends StatelessWidget {
  const SafeBottomActionBar({
    super.key,
    required this.child,
    this.avoidKeyboard = true,
    this.horizontalPadding,
    this.verticalPadding = AppSpacing.md,
    this.backgroundColor,
  });

  final Widget child;
  final bool avoidKeyboard;
  final double? horizontalPadding;
  final double verticalPadding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    Widget result = SafeArea(
      top: false,
      minimum: EdgeInsets.symmetric(vertical: verticalPadding),
      child: ResponsiveConstrainedPage(
        horizontalPadding: horizontalPadding,
        child: child,
      ),
    );

    result = ColoredBox(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: result,
    );

    return avoidKeyboard ? KeyboardInsetPadding(child: result) : result;
  }
}

/// A height-constrained dialog whose title, content, and actions stay
/// reachable by scrolling when text is large or the keyboard is visible.
class SafeScrollableDialog extends StatelessWidget {
  const SafeScrollableDialog({
    super.key,
    required this.content,
    this.title,
    this.actions = const [],
    this.maxWidth = 560,
    this.maxHeightFraction = 0.9,
    this.contentPadding = const EdgeInsets.all(AppSpacing.lg),
    this.scrollController,
  }) : assert(maxHeightFraction > 0 && maxHeightFraction <= 1);

  final Widget? title;
  final Widget content;
  final List<Widget> actions;
  final double maxWidth;
  final double maxHeightFraction;
  final EdgeInsetsGeometry contentPadding;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final unobscuredHeight = math.max(
      0.0,
      mediaQuery.size.height -
          mediaQuery.viewInsets.bottom -
          mediaQuery.padding.vertical,
    );
    final horizontalInset = ResponsiveStandards.horizontalPaddingFor(
      mediaQuery.size.width,
    );

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: AppSpacing.md,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: unobscuredHeight * maxHeightFraction,
        ),
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: SingleChildScrollView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: contentPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  DefaultTextStyle(
                    style: Theme.of(context).textTheme.headlineSmall ??
                        const TextStyle(),
                    child: title!,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                content,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: actions,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A keyboard-aware, height-constrained bottom-sheet surface.
///
/// The main [child] scrolls independently so [bottomAction] remains visible.
/// Use [showSafeModalBottomSheet] to get the required route configuration.
class SafeScrollableBottomSheet extends StatelessWidget {
  const SafeScrollableBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.bottomAction,
    this.maxHeightFraction = 0.9,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.scrollController,
    this.showDragHandle = true,
  }) : assert(maxHeightFraction > 0 && maxHeightFraction <= 1);

  final Widget child;
  final Widget? title;
  final Widget? bottomAction;
  final double maxHeightFraction;
  final EdgeInsetsGeometry padding;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = math.max(
      0.0,
      mediaQuery.size.height -
          mediaQuery.viewInsets.bottom -
          mediaQuery.padding.bottom,
    );

    return KeyboardInsetPadding(
      child: SafeArea(
        top: false,
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.lg),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: availableHeight * maxHeightFraction,
            ),
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showDragHandle)
                    Center(
                      child: Container(
                        width: AppSpacing.xl,
                        height: AppSpacing.xs,
                        margin: const EdgeInsets.only(top: AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(AppSpacing.xs),
                        ),
                      ),
                    ),
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        0,
                      ),
                      child: DefaultTextStyle(
                        style: Theme.of(context).textTheme.headlineSmall ??
                            const TextStyle(),
                        child: title!,
                      ),
                    ),
                  Flexible(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: padding,
                      child: child,
                    ),
                  ),
                  if (bottomAction != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: bottomAction,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a modal bottom sheet with the route settings required by
/// [SafeScrollableBottomSheet].
Future<T?> showSafeModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Widget? title,
  Widget? bottomAction,
  double maxHeightFraction = 0.9,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeScrollableBottomSheet(
      title: title,
      bottomAction: bottomAction,
      maxHeightFraction: maxHeightFraction,
      child: builder(sheetContext),
    ),
  );
}

/// Adds a minimum interactive layout region without changing child semantics.
class MinimumTapTarget extends StatelessWidget {
  const MinimumTapTarget({
    super.key,
    required this.child,
    this.minSize = ResponsiveStandards.minTapTarget,
  }) : assert(minSize >= ResponsiveStandards.minTapTarget);

  final Widget child;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: child,
      ),
    );
  }
}

/// Supplies a meaningful semantic label to a non-interactive custom widget.
class AccessibleLabel extends StatelessWidget {
  const AccessibleLabel({
    super.key,
    required this.label,
    required this.child,
    this.excludeChildSemantics = true,
    this.image = false,
    this.header = false,
    this.liveRegion = false,
  });

  final String label;
  final Widget child;
  final bool excludeChildSemantics;
  final bool image;
  final bool header;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: excludeChildSemantics,
      image: image,
      header: header,
      liveRegion: liveRegion,
      child: child,
    );
  }
}

/// A custom action with one semantic label and at least a 48dp hit target.
///
/// Prefer stock Material buttons when possible. Use this for bespoke icon or
/// card actions whose visual child is smaller than the required target.
class AccessibleTapTarget extends StatelessWidget {
  const AccessibleTapTarget({
    super.key,
    required this.label,
    required this.child,
    required this.onTap,
    this.minSize = ResponsiveStandards.minTapTarget,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: label,
      button: true,
      enabled: onTap != null,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MinimumTapTarget(
          minSize: minSize,
          child: InkResponse(
            onTap: onTap,
            excludeFromSemantics: true,
            containedInkWell: true,
            child: child,
          ),
        ),
      ),
    );
  }
}
