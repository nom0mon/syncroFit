import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A floating pill-shaped bottom navigation bar with four icon destinations.
///
/// Designed to be used as `bottomNavigationBar` in a [Scaffold] with
/// `extendBody: true`. The widget includes its own positioning (margin and
/// bottom offset) so it floats above the screen bottom.
///
/// Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 11.4
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
  static const double _horizontalMargin = 60;
  static const double _minTouchTarget = 48;

  static const List<_NavDestination> _destinations = [
    _NavDestination(
      inactiveIcon: Icons.grid_view,
      activeIcon: Icons.grid_view,
    ),
    _NavDestination(
      inactiveIcon: Icons.fitness_center_outlined,
      activeIcon: Icons.fitness_center,
    ),
    _NavDestination(
      inactiveIcon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
    ),
    _NavDestination(
      inactiveIcon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        _horizontalMargin,
        0,
        _horizontalMargin,
        _bottomOffset,
      ),
      height: _height,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.navBarFill,
        borderRadius: BorderRadius.circular(_cornerRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_destinations.length, (index) {
          final destination = _destinations[index];
          final isActive = index == selectedIndex;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onDestinationSelected(index),
            child: SizedBox(
              width: _minTouchTarget,
              height: _minTouchTarget,
              child: Center(
                child: Icon(
                  isActive ? destination.activeIcon : destination.inactiveIcon,
                  color: isActive
                      ? AppColors.textPrimary
                      : AppColors.iconInactive,
                  size: 24,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Internal model for a navigation destination's icon pair.
class _NavDestination {
  const _NavDestination({
    required this.inactiveIcon,
    required this.activeIcon,
  });

  final IconData inactiveIcon;
  final IconData activeIcon;
}
