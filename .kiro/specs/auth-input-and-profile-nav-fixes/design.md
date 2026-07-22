# Auth Input and Profile Nav Fixes — Bugfix Design

## Overview

This design addresses three UI bugs in the SyncroFit Flutter app:

1. **Auth TextField visibility** — The Login and Register screens have a white background (`Colors.white`) but inherit the dark theme's `InputDecorationTheme` when the app runs in dark mode. The dark theme uses white/light-grey borders (`AppColors.focusBorder`, `AppColors.containerBorder`) and white hint text (`AppColors.textHint`) which are invisible on white. The fix wraps auth screen TextFormFields with explicit light-theme-compatible `InputDecoration`.

2. **Edit Profile missing back button** — The Settings screen uses `context.go('/settings/edit-profile')` which replaces the navigation stack, preventing Flutter's AppBar from rendering an automatic back button. The fix changes this to `context.push(...)`.

3. **Search tab removal** — The 5th nav destination (Search) and its router branch must be removed entirely, leaving 4 tabs.

## Glossary

- **Bug_Condition (C)**: The set of conditions that trigger each bug — dark-themed InputDecoration on white auth screens, `go()` navigation to Edit Profile, or the presence of the Search tab
- **Property (P)**: The desired correct behavior — visible borders/hints on auth screens, a functioning back button on Edit Profile, and exactly 4 nav bar destinations
- **Preservation**: All existing functionality that must remain unchanged — form submission, navigation between other settings screens, and the 4 remaining nav destinations
- **`inputDecorationThemeDark()`**: The function in `component_themes.dart` that defines border/hint colors for dark mode (white/grey, invisible on white)
- **`inputDecorationTheme()`**: The function in `component_themes.dart` that defines border/hint colors for light mode (grey300 borders, grey500 hints, visible on white)
- **`FloatingPillNavBar`**: The shared widget in `floating_pill_nav_bar.dart` rendering the bottom navigation pill
- **`StatefulShellBranch`**: go_router construct that defines a tab in the `StatefulShellRoute`

## Bug Details

### Bug Condition

The bugs manifest under three independent conditions:

1. Auth screens use `backgroundColor: Colors.white` on the Scaffold but inherit `InputDecorationTheme` from the current app theme. When the app theme is dark, `inputDecorationThemeDark()` applies white borders and white hint text — invisible on white.
2. `SettingsMainScreen` uses `context.go('/settings/edit-profile')` which replaces the route stack, leaving no previous route for AppBar's automatic back button.
3. `FloatingPillNavBar._destinations` contains 5 entries (including Search) and `app_router.dart` has a 5th `StatefulShellBranch` for Search.

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type UIInteraction
  OUTPUT: boolean

  // Bug 1: Auth screen text fields with invisible styling
  LET authScreenActive = input.currentScreen IN ['LoginScreen', 'RegisterScreen']
  LET darkThemeApplied = input.appThemeMode == ThemeMode.dark
  LET fieldInteraction = input.interactionType IN ['view_unfocused_field', 'focus_field']
  LET bug1 = authScreenActive AND darkThemeApplied AND fieldInteraction

  // Bug 2: Edit Profile navigation without back button
  LET navigateToEditProfile = input.action == 'navigate_to_edit_profile'
  LET usesGoNavigation = navigationMethod == 'context.go'
  LET bug2 = navigateToEditProfile AND usesGoNavigation

  // Bug 3: Search destination present in nav bar
  LET navBarVisible = input.currentScreen HAS bottomNavBar
  LET searchDestinationExists = FloatingPillNavBar.destinations.length == 5
  LET bug3 = navBarVisible AND searchDestinationExists

  RETURN bug1 OR bug2 OR bug3
END FUNCTION
```

### Examples

- **Bug 1 (unfocused)**: User opens Login screen in dark mode → E-mail field shows no visible hint text (white `AppColors.textHint` on white background) and border is nearly invisible (`AppColors.containerBorder` = `#3D3D3D` on white)
- **Bug 1 (focused)**: User taps E-mail field on Login screen in dark mode → focused border uses `AppColors.focusBorder` (white) on white background, completely invisible
- **Bug 2**: User taps "Edit Profile" in Settings → `ProfileEditScreen` opens with no back button in AppBar, user is stranded
- **Bug 3**: User sees 5 icons in the bottom nav bar including a Search icon that should not exist

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Login form validation and submission (email/password authentication) must continue to work
- Register form validation and submission (name/email/password registration) must continue to work
- Profile edit form submission and success confirmation must continue to work
- Navigation between Settings → Notification Settings, Change Password, Trainers must continue with back buttons
- Dashboard, Exercises, Progress, and Community tabs must continue to navigate correctly
- The dark theme's `InputDecorationTheme` must remain unchanged for screens that actually use dark backgrounds (Dashboard, Settings, etc.)
- Auth screen layout, spacing, logo, buttons, and copyright footer must remain unchanged

**Scope:**
All inputs that do NOT involve auth screen TextFormField rendering, Edit Profile navigation from Settings, or the bottom nav bar Search destination should be completely unaffected by this fix. This includes:
- TextFormFields on other screens (Profile Setup, Settings sub-screens)
- Navigation via deep links or other entry points
- All workout, exercise, progress, and community features
- Theme application on dark-background screens

## Hypothesized Root Cause

Based on the bug analysis, the confirmed root causes are:

1. **Theme Inheritance Mismatch (Bug 1)**: The `LoginScreen` and `RegisterScreen` set `backgroundColor: Colors.white` on their Scaffold but do NOT override the inherited `InputDecorationTheme`. When `AppTheme.darkTheme` is active (which uses `inputDecorationThemeDark()`), the TextFormFields inherit:
   - `hintStyle: TextStyle(color: AppColors.textHint)` → 60% white (`#99FFFFFF`) on white = invisible
   - `enabledBorder` with `AppColors.containerBorder` → `#3D3D3D` on white = barely visible
   - `focusedBorder` with `AppColors.focusBorder` → pure white on white = invisible

2. **Declarative Navigation Replaces Stack (Bug 2)**: `context.go('/settings/edit-profile')` performs declarative navigation that replaces the route stack to match the target path. Since `/settings/edit-profile` is a top-level route (not nested under `/settings`), there is no parent route on the stack. Flutter's `AppBar` only shows a back button when `Navigator.canPop()` is true, which requires a previous route on the stack.

3. **Leftover Search Tab (Bug 3)**: The Search tab was added to the nav bar and router but should not exist. The `_destinations` list in `FloatingPillNavBar` has 5 entries, and `app_router.dart` defines a 5th `StatefulShellBranch` with `_searchNavigatorKey`.

## Correctness Properties

Property 1: Bug Condition - Auth TextField Visibility on White Background

_For any_ auth screen (Login or Register) displayed with a white background, regardless of the app's current theme mode, the TextFormFields SHALL display visible grey hint text when unfocused and a visible darker border when focused, using colors from the light input decoration theme (grey300 enabled border, grey900 focused border, grey500 hint text).

**Validates: Requirements 2.1, 2.2, 2.3**

Property 2: Bug Condition - Edit Profile Back Navigation

_For any_ navigation from the Settings screen to the Edit Profile screen, the Edit Profile AppBar SHALL display a back arrow button that, when tapped, returns the user to the Settings screen.

**Validates: Requirements 2.4**

Property 3: Bug Condition - Search Tab Removal

_For any_ screen that displays the bottom navigation bar, the nav bar SHALL render exactly 4 icon destinations (Dashboard, Workout, Calendar, Community) with no Search destination present.

**Validates: Requirements 2.5**

Property 4: Preservation - Auth Form Submission

_For any_ valid form submission on Login or Register screens, the fixed code SHALL produce the same authentication/registration behavior as the original code, preserving successful login navigation and registration flow.

**Validates: Requirements 3.1, 3.2**

Property 5: Preservation - Other Navigation and Theming

_For any_ navigation between Settings sub-screens (Notification Settings, Change Password, Trainers) and any TextFormField interaction on non-auth screens, the fixed code SHALL produce the same behavior as the original code, preserving back buttons, form styling, and correct theme application.

**Validates: Requirements 3.3, 3.4, 3.5, 3.6**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `lib/features/auth/screens/login_screen.dart`

**Changes**:
1. **Wrap with Theme widget**: Wrap the Scaffold's body (or the entire Scaffold) with a `Theme` widget that applies `AppTheme.lightTheme` to ensure all child widgets inherit light-mode InputDecoration. Alternatively, add explicit `InputDecoration` with light-theme colors to each TextFormField.

   Preferred approach: Wrap with `Theme(data: AppTheme.lightTheme, child: ...)` at the Scaffold level, which automatically fixes all TextFormFields and any future fields without per-field duplication.

---

**File**: `lib/features/auth/screens/register_screen.dart`

**Changes**:
2. **Same Theme wrapper**: Apply the same `Theme(data: AppTheme.lightTheme, child: ...)` wrapper to the RegisterScreen's Scaffold.

---

**File**: `lib/features/settings/screens/settings_main_screen.dart`

**Changes**:
3. **Change `go()` to `push()`**: Replace `context.go('/settings/edit-profile')` with `context.push('/settings/edit-profile')` in the Edit Profile ListTile's `onTap`. This pushes the route onto the navigator stack, allowing `ProfileEditScreen`'s AppBar to automatically show a back button.

---

**File**: `lib/shared/widgets/floating_pill_nav_bar.dart`

**Changes**:
4. **Remove Search destination**: Remove the 5th `_NavDestination` entry (the one with `Icons.search`) from the `_destinations` list, leaving exactly 4 destinations.
5. **Update doc comment**: Change "five icon destinations" to "four icon destinations" and update `selectedIndex` doc from "0–4" to "0–3".

---

**File**: `lib/core/router/app_router.dart`

**Changes**:
6. **Remove Search branch**: Remove the 5th `StatefulShellBranch` (Search tab) from the `branches` list in `StatefulShellRoute.indexedStack`.
7. **Remove `_searchNavigatorKey`**: Remove the `GlobalKey<NavigatorState>` declaration for search.
8. **Remove Search import**: Remove the import of `search_screen.dart`.

---

**File**: `lib/core/router/route_names.dart`

**Changes**:
9. **Remove or deprecate Search route name**: Remove `static const String search = '/search'` and its comment, or mark it deprecated if it may be used elsewhere.

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bugs on unfixed code, then verify the fixes work correctly and preserve existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bugs BEFORE implementing the fix. Confirm or refute the root cause analysis. If we refute, we will need to re-hypothesize.

**Test Plan**: Write widget tests that render auth screens under a dark theme and assert input decoration colors. Write navigation tests that verify `context.go()` behavior. Write widget tests that count nav bar destinations.

**Test Cases**:
1. **Auth hint visibility test**: Render `LoginScreen` inside a `MaterialApp` with `AppTheme.darkTheme` and assert that `TextFormField` hint text color is invisible on white (will fail to show visible hint on unfixed code)
2. **Auth border visibility test**: Render `LoginScreen` with dark theme, focus a field, and assert focused border color is white (invisible on white background — will demonstrate the bug on unfixed code)
3. **Edit Profile back button test**: Navigate to Edit Profile via `context.go()` and assert that `AppBar` has no back button (will confirm the bug on unfixed code)
4. **Search tab count test**: Render `FloatingPillNavBar` and assert 5 destinations exist (will confirm bug on unfixed code)

**Expected Counterexamples**:
- Hint text color resolves to `Color(0x99FFFFFF)` (white 60%) instead of `AppColors.grey500` (grey)
- Focused border color resolves to `Color(0xFFFFFFFF)` (white) instead of `AppColors.grey900` (dark)
- `Navigator.canPop()` returns false on Edit Profile screen
- Nav bar renders 5 icons instead of 4

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed function produces the expected behavior.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  IF input.bug == 'auth_field_visibility' THEN
    rendered := renderAuthScreen(themeMode: dark)
    hintColor := getHintStyle(rendered.textFormField).color
    ASSERT hintColor == AppColors.grey500  // visible on white
    borderColor := getFocusedBorderColor(rendered.textFormField)
    ASSERT borderColor == AppColors.grey900  // visible on white

  ELSE IF input.bug == 'edit_profile_back' THEN
    screen := navigateToEditProfile(method: push)
    ASSERT screen.appBar.leading IS BackButton
    ASSERT tapping(screen.appBar.leading) navigatesTo '/settings'

  ELSE IF input.bug == 'search_tab' THEN
    navBar := renderFloatingPillNavBar()
    ASSERT navBar.destinations.length == 4
    ASSERT navBar.destinations DOES NOT CONTAIN Icons.search
  END IF
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed function produces the same result as the original function.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT originalBehavior(input) == fixedBehavior(input)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many test cases automatically across input combinations (different form data, navigation paths)
- It catches edge cases that manual unit tests might miss (e.g., empty fields, special characters)
- It provides strong guarantees that behavior is unchanged for all non-buggy inputs

**Test Plan**: Observe behavior on UNFIXED code first for form submissions, other screen navigations, and remaining nav destinations, then write property-based tests capturing that behavior.

**Test Cases**:
1. **Login submission preservation**: Verify that login with valid credentials continues to authenticate and navigate to dashboard
2. **Register submission preservation**: Verify that register with valid data continues to create account and navigate to profile setup
3. **Settings sub-navigation preservation**: Verify that navigating to Notification Settings, Change Password from Settings continues to show back buttons
4. **Nav bar 4-tab preservation**: Verify that tapping each of the 4 remaining destinations navigates to the correct screen

### Unit Tests

- Test that auth screen TextFormFields render with visible hint text under both light and dark app themes
- Test that auth screen TextFormFields render with visible borders (enabled and focused states)
- Test that `ProfileEditScreen` AppBar contains a back button when navigated via `push`
- Test that `FloatingPillNavBar` renders exactly 4 destinations
- Test that router branches count is 4 (no search branch)

### Property-Based Tests

- Generate random email/password combinations and verify login form continues to validate and submit correctly
- Generate random theme modes and verify auth TextFormField decoration is always visible on white
- Generate random navigation sequences between settings sub-screens and verify back buttons persist
- Generate random tab indices (0–3) and verify nav bar selection/navigation works correctly

### Integration Tests

- Full auth flow: open app in dark mode → see visible Login fields → enter credentials → sign in → land on Dashboard
- Full settings flow: Dashboard → Settings → Edit Profile (back button visible) → tap back → return to Settings
- Full nav flow: verify 4-tab navigation cycle works with correct icons and screens
