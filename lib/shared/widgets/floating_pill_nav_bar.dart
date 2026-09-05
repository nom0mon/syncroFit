import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'responsive_layout.dart';

/// A floating pill-shaped bottom navigation bar with four icon destinations.
///
/// Designed to be used as `bottomNavigationBar` in a [Scaffold] with
/// `extendBody: true`. The bar adapts its horizontal inset, constrains itself
/// on tablets, and remains above Android gesture-navigation insets.
class FloatingPillNavBar extends StatelessWidget {
  const FloatingPillNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  /// Currently active tab index (0–3).
  final int selectedIndex;

  /// Callback fired when a destination icon is tapped.
  final ValueChanged<int> onDestinationSelected;

  static const double _height = 56;
  static const double _cornerRadius = 28;
  static const double _bottomOffset = 16;
  static const double _maxWidth = 400;
  static const double _minTouchTarget = 48;

  static const List<_NavDestination> _destinations = [
    _NavDestination(
      label: 'Dashboard',
      inactiveIcon: Icons.grid_view,
      activeIcon: Icons.grid_view,
    ),
    _NavDestination(
      label: 'Exercises',
      inactiveIcon: Icons.fitness_center_outlined,
      activeIcon: Icons.fitness_center,
    ),
    _NavDestination(
      label: 'Progress',
      inactiveIcon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
    ),
    _NavDestination(
      label: 'Community',
      inactiveIcon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = ResponsiveStandards.horizontalPaddingFor(
      MediaQuery.sizeOf(context).width,
    );

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: _bottomOffset),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: Container(
              height: _height,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.navBarFill,
                borderRadius: BorderRadius.circular(_cornerRadius),
              ),
              child: Row(
                children: List.generate(_destinations.length, (index) {
                  final destination = _destinations[index];
                  final isActive = index == selectedIndex;

                  return Expanded(
                    child: Semantics(
                      label: destination.label,
                      button: true,
                      selected: isActive,
                      child: Tooltip(
                        message: destination.label,
                        child: InkResponse(
                          onTap: () => onDestinationSelected(index),
                          containedInkWell: true,
                          excludeFromSemantics: true,
                          child: SizedBox(
                            height: _minTouchTarget,
                            child: Center(
                              child: ExcludeSemantics(
                                child: Icon(
                                  isActive
                                      ? destination.activeIcon
                                      : destination.inactiveIcon,
                                  color: isActive
                                      ? AppColors.textPrimary
                                      : AppColors.iconInactive,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal model for a navigation destination's icon pair and semantic label.
class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.inactiveIcon,
    required this.activeIcon,
  });

  final String label;
  final IconData inactiveIcon;
  final IconData activeIcon;
}
