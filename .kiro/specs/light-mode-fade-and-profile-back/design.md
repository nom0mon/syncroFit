# Light Mode Fade and Profile Back Bugfix Design

## Overview

This design addresses five related UI bugs in SyncroFit: (1) the `EdgeFadeGradient` widget hardcodes black regardless of theme, causing dark bands in light mode; (2) the Progress and Community screens lack fade overlays entirely; (3) settings sub-screen navigation uses `context.go()` instead of `context.push()`, causing the system back button to exit the app; (4) the Edit Profile screen lacks an explicit back button in the AppBar; and (5) the hardcoded black fade bands cause pixel overflow artifacts in light mode. The fix strategy is minimal and targeted — theme-aware color in the gradient widget, consistent fade overlays on all scrollable module screens, and corrected navigation calls.

## Glossary

- **Bug_Condition (C)**: The set of conditions that trigger the visual or navigation bugs — light mode active with fade gradients rendered, missing fade overlays, or back navigation on settings sub-screens
- **Property (P)**: The desired correct behavior — theme-aware fade colors, consistent fade overlays on all scrollable screens, and proper back navigation
- **Preservation**: Existing dark-mode appearance, mouse/tap interactions, profile save behavior, and bottom navigation that must remain unchanged
- **EdgeFadeGradient**: The widget in `lib/shared/widgets/edge_fade_gradient.dart` that renders top/bottom gradient overlays on scrollable content
- **context.go()**: GoRouter method that replaces the entire navigation stack (no back navigation possible)
- **context.push()**: GoRouter method that pushes a route onto the stack (preserves back navigation)
- **scaffoldBackgroundColor**: The theme-provided scaffold background color that adapts to light/dark mode

## Bug Details

### Bug Condition

The bugs manifest under the following conditions:

1. **Fade color bug**: When the app is in light mode AND any screen renders the `EdgeFadeGradient` widget, the gradient uses hardcoded `AppColors.scaffoldBlack` (#000000) instead of the theme's scaffold background color.
2. **Missing fade overlays**: When the user navigates to Progress Summary or Community Feed screens, no `EdgeFadeGradient` overlays are present despite these being scrollable content screens.
3. **Back navigation bug**: When the user is on Notifications or Change Password settings sub-screens and presses the system back button, `context.go()` has replaced the route stack so there is nothing to pop back to.
4. **Missing back button**: When the user is on the Edit Profile screen, the AppBar does not render an explicit leading back button widget.
5. **Pixel overflow**: The black gradient bands overlaid on light content create visual overflow artifacts.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type AppState (theme mode, current screen, user action)
  OUTPUT: boolean
  
  RETURN (input.themeMode == ThemeMode.light AND input.screenUsesEdgeFadeGradient == true)
         OR (input.currentScreen IN ['ProgressSummaryScreen', 'FeedScreen'] AND input.expectsFadeOverlay == true)
         OR (input.currentScreen IN ['NotificationSettingsScreen', 'ChangePasswordScreen'] AND input.action == 'systemBackPressed')
         OR (input.currentScreen == 'ProfileEditScreen' AND input.expectsVisibleBackButton == true)
END FUNCTION
```

### Examples

- **Light mode fade**: User enables light mode, opens Dashboard → black gradient bands appear at top/bottom of scrollable content against a white background (expected: white/transparent gradient blending with light scaffold)
- **Missing overlay on Progress**: User navigates to Progress tab → content scrolls edge-to-edge without fade effect (expected: matching top/bottom fade overlays like Dashboard)
- **Missing overlay on Community**: User navigates to Community tab → post list scrolls without fade effect (expected: matching top/bottom fade overlays like Exercise Library)
- **Back exits app on Notifications**: User opens Settings → taps Notification Settings → presses system back → app exits (expected: returns to Settings screen)
- **Back exits app on Change Password**: User opens Settings → taps Change Password → presses system back → app exits (expected: returns to Settings screen)
- **No back button on Edit Profile**: User opens Settings → taps Edit Profile → no visible back arrow in AppBar (expected: back arrow icon in top-left)
- **Dark mode still works**: User in dark mode opens Dashboard → black gradient bands blend correctly with dark scaffold (expected: unchanged behavior)

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Dark mode fade gradients must continue to render with black/dark color that blends with the dark scaffold background
- Mouse/tap interactions on all buttons, cards, and list tiles must continue to work as before
- Profile update form submission, validation, and success/error feedback must remain unchanged
- Bottom navigation bar switching between Dashboard, Exercises, Progress, and Community tabs must remain unaffected
- Edit Profile navigation via `context.push` must continue to work correctly
- All existing `EdgeFadeGradient` usage on Dashboard and Exercise Library screens must continue to render correctly in dark mode
- Settings screen layout, theme toggle, and list tile structure must remain unchanged

**Scope:**
All inputs that do NOT involve light-mode rendering of fade gradients, the Progress/Community screen layouts, settings sub-screen back navigation, or the Edit Profile AppBar should be completely unaffected by this fix. This includes:
- All dark mode rendering
- All tap/click interactions on existing UI elements
- All form submissions and data persistence
- All workout flows (active, rest, summary)
- All exercise detail navigation

## Hypothesized Root Cause

Based on the bug description and code analysis, the confirmed root causes are:

1. **Hardcoded color in EdgeFadeGradient**: The widget at `lib/shared/widgets/edge_fade_gradient.dart` directly references `AppColors.scaffoldBlack` (a static `Color(0xFF000000)`) in its `build` method. It does not accept a `BuildContext` to read `Theme.of(context).scaffoldBackgroundColor`. This causes the gradient to always be black regardless of theme mode.

2. **Missing Stack + EdgeFadeGradient on Progress screen**: `ProgressSummaryScreen` uses a plain `SingleChildScrollView` returned directly from the Scaffold body without wrapping it in a `Stack` with `EdgeFadeGradient` overlays.

3. **Missing Stack + EdgeFadeGradient on Community screen**: `FeedScreen` uses a plain `ListView.builder` returned directly from the Scaffold body without wrapping it in a `Stack` with `EdgeFadeGradient` overlays.

4. **Incorrect navigation method in settings**: In `settings_main_screen.dart`, Notification Settings uses `context.go('/settings/notifications')` and Change Password uses `context.go('/settings/change-password')`. The `go()` method replaces the route stack entirely, so the system back button has nowhere to return to. Edit Profile already correctly uses `context.push(...)`.

5. **Missing explicit back button on Edit Profile**: `ProfileEditScreen` has `AppBar(title: const Text('Edit Profile'))` without a `leading` widget. Since all settings routes use `parentNavigatorKey: _rootNavigatorKey`, the implicit back button may not appear reliably.

6. **Pixel overflow from dark bands**: The black gradient rendering over light content creates visual contrast artifacts that manifest as apparent pixel overflow. Fixing the theme-aware color resolves this.

## Correctness Properties

Property 1: Bug Condition - Theme-Aware Fade Gradient Color

_For any_ screen rendering the `EdgeFadeGradient` widget in any theme mode, the gradient color SHALL match the current theme's scaffold background color (`Theme.of(context).scaffoldBackgroundColor`), producing a visually seamless fade in both light and dark modes.

**Validates: Requirements 2.1, 2.2, 2.3, 2.8**

Property 2: Bug Condition - Consistent Fade Overlays on All Scrollable Module Screens

_For any_ scrollable module screen (Dashboard, Exercise Library, Progress Summary, Community Feed), the screen SHALL display `EdgeFadeGradient` overlays at both the top and bottom edges of the scrollable content area.

**Validates: Requirements 2.4, 2.5**

Property 3: Bug Condition - Settings Sub-Screen Back Navigation

_For any_ settings sub-screen (Notifications, Change Password), pressing the system back button SHALL navigate back to the Settings screen without exiting the application.

**Validates: Requirements 2.6**

Property 4: Bug Condition - Edit Profile Visible Back Button

_For any_ state of the Edit Profile screen, the AppBar SHALL display a visible back button icon in the leading position that navigates back to the previous screen when tapped.

**Validates: Requirements 2.7**

Property 5: Preservation - Dark Mode Appearance Unchanged

_For any_ screen rendering the `EdgeFadeGradient` widget in dark mode, the gradient color SHALL be black (matching the dark scaffold), producing the same visual result as before the fix.

**Validates: Requirements 3.1, 3.2, 3.5**

Property 6: Preservation - Existing Navigation and Interactions Unchanged

_For any_ user interaction that does NOT involve the system back button on settings sub-screens or the Edit Profile back button, the navigation and behavior SHALL produce exactly the same result as the original code, preserving all existing functionality.

**Validates: Requirements 3.3, 3.4, 3.6**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `lib/shared/widgets/edge_fade_gradient.dart`

**Function**: `EdgeFadeGradient.build`

**Specific Changes**:
1. **Replace hardcoded color with theme-aware color**: Change `AppColors.scaffoldBlack` to `Theme.of(context).scaffoldBackgroundColor` in the gradient colors list. This makes the widget automatically adapt to the current theme mode.
2. **Remove unused import**: Remove the `import '../../core/theme/app_colors.dart'` since `AppColors.scaffoldBlack` will no longer be referenced.

---

**File**: `lib/features/progress/screens/progress_summary_screen.dart`

**Widget**: `_ProgressContent.build`

**Specific Changes**:
3. **Wrap SingleChildScrollView in a Stack**: Replace the direct `SingleChildScrollView` return with a `Stack` containing the `SingleChildScrollView` and two `Positioned` `EdgeFadeGradient` widgets (top and bottom), matching the pattern used in `DashboardScreen`.
4. **Add EdgeFadeGradient import**: Add `import '../../../shared/widgets/edge_fade_gradient.dart'`.

---

**File**: `lib/features/community/screens/feed_screen.dart`

**Widget**: `FeedScreen.build` (inside the `data` callback)

**Specific Changes**:
5. **Wrap ListView.builder in a Stack**: Replace the direct `ListView.builder` return with a `Stack` containing the `ListView.builder` and two `Positioned` `EdgeFadeGradient` widgets (top and bottom), matching the pattern used in `ExerciseListScreen`.
6. **Add EdgeFadeGradient import**: Add `import '../../../shared/widgets/edge_fade_gradient.dart'`.

---

**File**: `lib/features/settings/screens/settings_main_screen.dart`

**Function**: `SettingsMainScreen.build`

**Specific Changes**:
7. **Change `context.go` to `context.push` for Notifications**: Change `context.go('/settings/notifications')` to `context.push('/settings/notifications')` so the Settings screen remains in the navigation stack.
8. **Change `context.go` to `context.push` for Change Password**: Change `context.go('/settings/change-password')` to `context.push('/settings/change-password')` so the Settings screen remains in the navigation stack.

---

**File**: `lib/features/profile/screens/profile_edit_screen.dart`

**Widget**: `_ProfileEditScreenState.build`

**Specific Changes**:
9. **Add explicit leading back button to AppBar**: Add `leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop())` to the AppBar widget.
10. **Add GoRouter import**: Add `import 'package:go_router/go_router.dart'` for `context.pop()`.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bugs on unfixed code, then verify the fixes work correctly and preserve existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bugs BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write widget tests that render the affected widgets under both theme modes and inspect the rendered gradient colors, check for presence of `EdgeFadeGradient` in widget trees, and simulate back navigation on settings sub-screens.

**Test Cases**:
1. **Light Mode Fade Color Test**: Render `EdgeFadeGradient` inside a light theme `MaterialApp` and assert the gradient uses the scaffold background color (will fail on unfixed code — gradient uses black)
2. **Progress Screen Fade Overlay Test**: Render `ProgressSummaryScreen` and assert `EdgeFadeGradient` widgets exist in the widget tree (will fail on unfixed code — no overlays present)
3. **Community Screen Fade Overlay Test**: Render `FeedScreen` and assert `EdgeFadeGradient` widgets exist in the widget tree (will fail on unfixed code — no overlays present)
4. **Settings Back Navigation Test**: Simulate navigating to Notifications via `context.go`, then attempt to pop — assert navigation stack is not empty (will fail on unfixed code — stack is empty)
5. **Edit Profile Back Button Test**: Render `ProfileEditScreen` and find an `IconButton` with `Icons.arrow_back` in the AppBar (will fail on unfixed code — no leading widget)

**Expected Counterexamples**:
- `EdgeFadeGradient` renders with `Color(0xFF000000)` regardless of theme mode
- `ProgressSummaryScreen` widget tree contains zero `EdgeFadeGradient` instances
- `FeedScreen` widget tree contains zero `EdgeFadeGradient` instances
- After `context.go('/settings/notifications')`, the navigator cannot pop back
- `ProfileEditScreen` AppBar has no leading `IconButton`

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed functions produce the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  IF input.type == 'fadeColor' THEN
    widget := buildEdgeFadeGradient(context_with_theme(input.themeMode))
    gradientColor := extractGradientColor(widget)
    ASSERT gradientColor == Theme.of(context).scaffoldBackgroundColor
  ELSE IF input.type == 'missingOverlay' THEN
    screen := buildScreen(input.screenName)
    ASSERT countWidgetsOfType(screen, EdgeFadeGradient) == 2
  ELSE IF input.type == 'backNavigation' THEN
    navigateToSubScreen(input.route)
    pressSystemBack()
    ASSERT currentRoute == '/settings'
  ELSE IF input.type == 'missingBackButton' THEN
    screen := buildProfileEditScreen()
    ASSERT findLeadingIconButton(screen) != null
  END IF
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed functions produce the same result as the original functions.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT originalBehavior(input) == fixedBehavior(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many theme/screen combinations to verify gradient colors match expectations
- It catches edge cases in navigation state that manual unit tests might miss
- It provides strong guarantees that dark mode behavior and existing interactions are unchanged

**Test Plan**: Observe behavior on UNFIXED code first for dark mode rendering, tap interactions, and profile submission flows, then write tests capturing that behavior.

**Test Cases**:
1. **Dark Mode Fade Color Preservation**: Render `EdgeFadeGradient` in dark theme and verify gradient uses black color (same as current behavior)
2. **Dashboard Fade Preservation**: Render `DashboardScreen` in dark mode and verify two `EdgeFadeGradient` widgets are present and render black
3. **Edit Profile Push Navigation Preservation**: Verify `context.push('/settings/edit-profile')` still works correctly and allows pop back
4. **Bottom Navigation Preservation**: Verify tab switching between all four modules continues to work after the fix
5. **Profile Form Submission Preservation**: Verify submitting profile edit form still calls `updateProfile` and shows SnackBar feedback

### Unit Tests

- Test `EdgeFadeGradient` renders correct color for light theme (white scaffold background)
- Test `EdgeFadeGradient` renders correct color for dark theme (black scaffold background)
- Test `EdgeFadeGradient` with custom height parameter still works
- Test that `IgnorePointer` wrapper is preserved (touch events pass through)
- Test Settings navigation uses `push` for all sub-screens
- Test Edit Profile AppBar has leading back button

### Property-Based Tests

- Generate random `ThemeData` configurations with varying scaffold background colors and verify `EdgeFadeGradient` always uses the theme's scaffold color
- Generate random sequences of settings navigation actions and verify the back button always returns to Settings
- Generate various screen states for Progress and Community and verify `EdgeFadeGradient` overlays are always present in the widget tree

### Integration Tests

- Test full flow: switch to light mode → navigate to Dashboard → verify fade bands blend with light background
- Test full flow: navigate to Settings → Notifications → press system back → verify return to Settings
- Test full flow: navigate to Settings → Edit Profile → tap back arrow → verify return to Settings
- Test full flow: navigate between all four tabs and verify consistent fade overlay behavior
