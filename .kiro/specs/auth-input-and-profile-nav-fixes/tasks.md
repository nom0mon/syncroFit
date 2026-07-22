# Implementation Plan

## Overview

Fix three UI bugs in SyncroFit: invisible auth TextFields when dark theme is active, missing back button on Edit Profile screen, and removal of the unwanted Search tab from navigation. Uses exploratory bug condition methodology — write tests BEFORE fix to understand the bugs, then implement and validate.

## Tasks

- [x] 1. Write bug condition exploration test
  - **Property 1: Bug Condition** - Auth TextField Visibility, Edit Profile Back Button, and Search Tab Presence
  - **CRITICAL**: This test MUST FAIL on unfixed code - failure confirms the bugs exist
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior - it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples that demonstrate the three bugs exist
  - **Scoped PBT Approach**: Scope property to concrete failing cases for each bug:
    - Bug 1: Render `LoginScreen` and `RegisterScreen` inside `MaterialApp(theme: AppTheme.darkTheme)`. Assert that TextFormField hint text color equals `AppColors.grey500` (visible grey) and enabled border color equals `AppColors.grey300`, focused border color equals `AppColors.grey900`. These will FAIL because unfixed code inherits dark theme's invisible white/light decorations on white background.
    - Bug 2: Navigate to `/settings/edit-profile` via the Settings screen's `context.go()` call and assert `AppBar` leading widget contains a back button. This will FAIL because `go()` replaces the stack so `Navigator.canPop()` returns false.
    - Bug 3: Render `FloatingPillNavBar` and assert `_destinations.length == 4` and no `Icons.search` icon present. This will FAIL because unfixed code has 5 destinations including Search.
  - `isBugCondition(input)`: (authScreen AND darkTheme AND fieldInteraction) OR (navigateToEditProfile AND usesGoNavigation) OR (navBarVisible AND searchDestinationExists)
  - Expected behavior assertions: grey500 hint, grey300/grey900 borders on auth; back button present on Edit Profile; exactly 4 nav destinations
  - Run test on UNFIXED code
  - **EXPECTED OUTCOME**: Test FAILS (this is correct - it proves the bugs exist)
  - Document counterexamples found: hint color resolves to `Color(0x99FFFFFF)` instead of grey500; border resolves to white instead of grey900; no back button widget found; 5 destinations instead of 4
  - Mark task complete when test is written, run, and failure is documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Auth Form Submission, Settings Navigation, and Nav Bar Tab Behavior
  - **IMPORTANT**: Follow observation-first methodology
  - Observe on UNFIXED code:
    - Login with valid credentials (`test@test.com` / `password123`) authenticates successfully and navigates to dashboard
    - Register with valid data (`TestUser` / `test@test.com` / `password123`) registers successfully and navigates to profile setup
    - Navigating from Settings to Notification Settings and Change Password shows back buttons
    - Tapping nav destinations 0-3 (Dashboard, Exercises, Progress, Community) navigates to correct screens
  - Write property-based tests capturing observed behavior:
    - For all valid email/password combinations matching validation rules, login form submission triggers authentication
    - For all valid name/email/password combinations, register form submission triggers registration
    - For all Settings sub-screen navigation paths (notifications, change-password, trainers), back buttons are present
    - For all tab indices 0-3, nav bar selection highlights correct icon and triggers `onDestinationSelected`
  - Verify tests pass on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 3. Fix for Auth TextField visibility, Edit Profile back button, and Search tab removal

  - [x] 3.1 Wrap auth screens with light theme to fix TextField visibility
    - In `lib/features/auth/screens/login_screen.dart`: Import `app_theme.dart` and wrap the `Scaffold` with `Theme(data: AppTheme.lightTheme, child: ...)` so all TextFormFields inherit visible light-mode InputDecoration (grey500 hints, grey300 enabled borders, grey900 focused borders) regardless of app theme mode
    - In `lib/features/auth/screens/register_screen.dart`: Apply the same `Theme(data: AppTheme.lightTheme, child: ...)` wrapper around the `Scaffold`
    - _Bug_Condition: isBugCondition(input) where input.currentScreen IN ['LoginScreen', 'RegisterScreen'] AND input.appThemeMode == ThemeMode.dark_
    - _Expected_Behavior: TextFormField hint color == AppColors.grey500, enabled border == AppColors.grey300, focused border == AppColors.grey900_
    - _Preservation: Auth screen layout, spacing, logo, buttons, copyright footer unchanged; dark theme InputDecoration unchanged for other screens_
    - _Requirements: 2.1, 2.2, 2.3, 3.4_

  - [x] 3.2 Change Edit Profile navigation from go() to push()
    - In `lib/features/settings/screens/settings_main_screen.dart`: Change `context.go('/settings/edit-profile')` to `context.push('/settings/edit-profile')` in the Edit Profile ListTile's `onTap` callback
    - This pushes the route onto the navigator stack so Flutter's AppBar automatically renders a back button
    - _Bug_Condition: isBugCondition(input) where input.action == 'navigate_to_edit_profile' AND navigationMethod == 'context.go'_
    - _Expected_Behavior: ProfileEditScreen AppBar displays back arrow that navigates to Settings when tapped_
    - _Preservation: Navigation to other Settings sub-screens (notifications, change-password, trainers) remains unchanged_
    - _Requirements: 2.4, 3.5_

  - [x] 3.3 Remove Search tab from navigation bar and router
    - In `lib/shared/widgets/floating_pill_nav_bar.dart`: Remove the 5th `_NavDestination` entry (`Icons.search`) from the `_destinations` list; update doc comment from "five" to "four" and selectedIndex range from "0–4" to "0–3"
    - In `lib/core/router/app_router.dart`: Remove the 5th `StatefulShellBranch` (search), remove `_searchNavigatorKey` declaration, remove `import '../../features/search/screens/search_screen.dart'`
    - In `lib/core/router/route_names.dart`: Remove `static const String search = '/search'` and its comment
    - _Bug_Condition: isBugCondition(input) where FloatingPillNavBar.destinations.length == 5 AND searchDestinationExists_
    - _Expected_Behavior: Nav bar renders exactly 4 destinations, no Search icon, no search route in router_
    - _Preservation: Dashboard, Exercises, Progress, Community tabs continue to navigate correctly with correct icons and active states_
    - _Requirements: 2.5, 3.6_

  - [x] 3.4 Verify bug condition exploration test now passes
    - **Property 1: Expected Behavior** - Auth TextField Visibility, Edit Profile Back Button, and Search Tab Removal
    - **IMPORTANT**: Re-run the SAME test from task 1 - do NOT write a new test
    - The test from task 1 encodes the expected behavior for all three bugs
    - When this test passes, it confirms: visible hints/borders on auth screens, back button on Edit Profile, exactly 4 nav destinations
    - Run bug condition exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms all three bugs are fixed)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 3.5 Verify preservation tests still pass
    - **Property 2: Preservation** - Auth Form Submission, Settings Navigation, and Nav Bar Tab Behavior
    - **IMPORTANT**: Re-run the SAME tests from task 2 - do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions in form submission, other navigation, or remaining tab behavior)
    - Confirm all tests still pass after fix (no regressions)

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Task Dependency Graph

```json
{
  "waves": [
    { "tasks": ["1", "2"] },
    { "tasks": ["3.1", "3.2", "3.3"] },
    { "tasks": ["3.4", "3.5"] },
    { "tasks": ["4"] }
  ]
}
```

## Notes

- Tasks 1 and 2 are independent and can be worked on in parallel
- Tasks 3.1, 3.2, and 3.3 are independent implementation changes and can be done in any order
- Tasks 3.4 and 3.5 depend on all implementation tasks (3.1-3.3) being complete
- Task 4 is the final checkpoint after all verification passes
