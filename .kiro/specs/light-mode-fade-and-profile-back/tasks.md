# Implementation Plan

## Overview

This task list follows the exploratory bugfix workflow to fix light mode fade color, missing overlays on Progress/Community screens, settings sub-screen back navigation, and the Edit Profile back button. Tests are written BEFORE the fix to understand the bug, then the fix is applied and validated.

## Tasks

- [ ] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Light Mode Fade, Missing Overlays, Navigation, and Back Button
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bugs exist
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the bugs exist
  - **Scoped PBT Approach**: Scope properties to concrete failing cases for each bug condition:
    - Render `EdgeFadeGradient` inside a light-theme `MaterialApp` and assert gradient color equals `Theme.of(context).scaffoldBackgroundColor` (white), NOT hardcoded black
    - Render `ProgressSummaryScreen` and assert widget tree contains at least 2 `EdgeFadeGradient` instances (top and bottom overlays)
    - Render `FeedScreen` and assert widget tree contains at least 2 `EdgeFadeGradient` instances (top and bottom overlays)
    - Simulate navigation to `/settings/notifications` and verify navigator can pop back to `/settings` (not exit app)
    - Simulate navigation to `/settings/change-password` and verify navigator can pop back to `/settings` (not exit app)
    - Render `ProfileEditScreen` and assert AppBar contains a leading `IconButton` with `Icons.arrow_back`
  - **Bug Condition from design**: `isBugCondition(input)` where:
    - `input.themeMode == ThemeMode.light AND input.screenUsesEdgeFadeGradient == true`
    - `input.currentScreen IN ['ProgressSummaryScreen', 'FeedScreen'] AND input.expectsFadeOverlay == true`
    - `input.currentScreen IN ['NotificationSettingsScreen', 'ChangePasswordScreen'] AND input.action == 'systemBackPressed'`
    - `input.currentScreen == 'ProfileEditScreen' AND input.expectsVisibleBackButton == true`
  - **Expected Behavior**: Gradient uses theme scaffold color; Progress/Community have overlays; back button returns to Settings; Edit Profile has leading icon
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bugs exist)
  - Document counterexamples found:
    - `EdgeFadeGradient` renders `Color(0xFF000000)` regardless of theme mode
    - `ProgressSummaryScreen` widget tree contains zero `EdgeFadeGradient` instances
    - `FeedScreen` widget tree contains zero `EdgeFadeGradient` instances
    - After `context.go('/settings/notifications')`, navigator cannot pop back
    - `ProfileEditScreen` AppBar has no leading `IconButton`
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_

- [ ] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Dark Mode Fade, Existing Navigation, and Profile Form Behavior
  - **IMPORTANT**: Follow observation-first methodology
  - Observe behavior on UNFIXED code for non-buggy inputs:
    - Observe: `EdgeFadeGradient` in dark theme renders gradient using black color matching dark scaffold background
    - Observe: `DashboardScreen` in dark mode contains 2 `EdgeFadeGradient` widgets rendering black
    - Observe: `ExerciseListScreen` in dark mode contains 2 `EdgeFadeGradient` widgets rendering black
    - Observe: `context.push('/settings/edit-profile')` works correctly and allows pop back to Settings
    - Observe: Bottom navigation switching between Dashboard, Exercises, Progress, Community tabs works correctly
    - Observe: Profile edit form submission calls `updateProfile` and shows SnackBar feedback
  - Write property-based tests capturing observed behavior patterns:
    - For all dark-mode theme configurations, `EdgeFadeGradient` gradient color equals the theme's scaffold background color (black)
    - For all existing screens with fade overlays (Dashboard, Exercise Library), `EdgeFadeGradient` count is 2 in dark mode
    - For Edit Profile navigation via `context.push`, pop returns to Settings screen
    - Bottom navigation tab switches preserve screen state and do not disrupt navigation stack
  - Run tests on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [ ] 3. Fix for light mode fade color, missing overlays, settings back navigation, and Edit Profile back button

  - [ ] 3.1 Fix EdgeFadeGradient to use theme-aware color
    - In `lib/shared/widgets/edge_fade_gradient.dart`, replace hardcoded `AppColors.scaffoldBlack` with `Theme.of(context).scaffoldBackgroundColor`
    - Remove unused `import '../../core/theme/app_colors.dart'` if no longer needed
    - This makes the gradient automatically adapt to light/dark mode
    - _Bug_Condition: isBugCondition(input) where input.themeMode == ThemeMode.light AND input.screenUsesEdgeFadeGradient == true_
    - _Expected_Behavior: gradientColor == Theme.of(context).scaffoldBackgroundColor for all theme modes_
    - _Preservation: Dark mode continues to render black gradient (scaffoldBackgroundColor is black in dark mode)_
    - _Requirements: 2.1, 2.2, 2.3, 2.8_

  - [ ] 3.2 Add EdgeFadeGradient overlays to Progress Summary screen
    - In `lib/features/progress/screens/progress_summary_screen.dart`, wrap the `SingleChildScrollView` in a `Stack`
    - Add two `Positioned` `EdgeFadeGradient` widgets (top and bottom) matching the pattern from `DashboardScreen`
    - Add `import '../../../shared/widgets/edge_fade_gradient.dart'`
    - _Bug_Condition: isBugCondition(input) where input.currentScreen == 'ProgressSummaryScreen' AND input.expectsFadeOverlay == true_
    - _Expected_Behavior: ProgressSummaryScreen widget tree contains 2 EdgeFadeGradient instances_
    - _Preservation: Existing scroll behavior and content layout unchanged_
    - _Requirements: 2.4_

  - [ ] 3.3 Add EdgeFadeGradient overlays to Community Feed screen
    - In `lib/features/community/screens/feed_screen.dart`, wrap the `ListView.builder` in a `Stack`
    - Add two `Positioned` `EdgeFadeGradient` widgets (top and bottom) matching the pattern from `ExerciseListScreen`
    - Add `import '../../../shared/widgets/edge_fade_gradient.dart'`
    - _Bug_Condition: isBugCondition(input) where input.currentScreen == 'FeedScreen' AND input.expectsFadeOverlay == true_
    - _Expected_Behavior: FeedScreen widget tree contains 2 EdgeFadeGradient instances_
    - _Preservation: Existing list scroll behavior and content layout unchanged_
    - _Requirements: 2.5_

  - [ ] 3.4 Fix settings sub-screen navigation to use context.push()
    - In `lib/features/settings/screens/settings_main_screen.dart`, change `context.go('/settings/notifications')` to `context.push('/settings/notifications')`
    - Change `context.go('/settings/change-password')` to `context.push('/settings/change-password')`
    - This preserves the Settings screen in the navigation stack so system back button returns to it
    - _Bug_Condition: isBugCondition(input) where input.currentScreen IN ['NotificationSettingsScreen', 'ChangePasswordScreen'] AND input.action == 'systemBackPressed'_
    - _Expected_Behavior: After navigating to sub-screen and pressing back, currentRoute == '/settings'_
    - _Preservation: Edit Profile navigation already uses context.push and must remain unchanged_
    - _Requirements: 2.6_

  - [ ] 3.5 Add explicit back button to Edit Profile AppBar
    - In `lib/features/profile/screens/profile_edit_screen.dart`, add `leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop())` to the AppBar
    - Add `import 'package:go_router/go_router.dart'` if not already present for `context.pop()`
    - _Bug_Condition: isBugCondition(input) where input.currentScreen == 'ProfileEditScreen' AND input.expectsVisibleBackButton == true_
    - _Expected_Behavior: AppBar contains a leading IconButton with Icons.arrow_back that calls context.pop()_
    - _Preservation: Profile form submission, validation, and save behavior unchanged_
    - _Requirements: 2.7_

  - [ ] 3.6 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Light Mode Fade, Missing Overlays, Navigation, and Back Button
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms the expected behavior is satisfied
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bugs are fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8_

  - [ ] 3.7 Verify preservation tests still pass
    - **Property 2: Preservation** - Dark Mode Fade, Existing Navigation, and Profile Form Behavior
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions)
    - Confirm all tests still pass after fix (no regressions)

- [ ] 4. Checkpoint - Ensure all tests pass
  - Run full test suite to verify all exploration and preservation tests pass
  - Verify no new warnings or errors introduced
  - Ensure all tests pass, ask the user if questions arise

## Task Dependency Graph

```json
{
  "waves": [
    ["1"],
    ["2"],
    ["3.1", "3.2", "3.3", "3.4", "3.5"],
    ["3.6", "3.7"],
    ["4"]
  ]
}
```

Tasks must be executed in order:
- Wave 1: Task 1 (exploration test) must be completed first to understand the bugs
- Wave 2: Task 2 (preservation test) captures baseline behavior on unfixed code
- Wave 3: Implementation sub-tasks (3.1-3.5) can be done in parallel after tests are written
- Wave 4: Verification sub-tasks (3.6, 3.7) re-run tests after implementation
- Wave 5: Task 4 (checkpoint) runs last to ensure all tests pass

## Notes

- This bugfix covers 5 related UI issues that share a common theme: light-mode visual correctness and navigation reliability
- The `EdgeFadeGradient` fix (3.1) is the highest-impact change as it resolves both the dark band issue AND the pixel overflow issue
- The navigation fix (3.4) changes `context.go()` to `context.push()` which is a minimal, low-risk change
- The Progress/Community overlay additions (3.2, 3.3) follow existing patterns from Dashboard and Exercise Library screens
- Property-based tests focus on theme-color invariants and navigation stack preservation
