# Implementation Plan: Geist UI Redesign

## Overview

Redesign SyncroFit's visual layer to adopt a Geist-inspired dark monochrome aesthetic. The implementation modifies the existing theme system (fonts, colors, component styles), creates shared reusable widgets (SectionHeader, BodySilhouetteWidget, EdgeFadeGradient), refactors the Exercise Library screen, rebuilds the Dashboard with decomposed sub-widgets, and replaces the bottom navigation bar with a floating pill-shaped variant. No new packages are required — Geist/Geist Mono are available via the existing `google_fonts` dependency, and `fl_chart` handles charting.

## Tasks

- [x] 1. Update theme system: colors, fonts, and component styles
  - [x] 1.1 Refactor `AppColors` to add Geist dark palette constants
    - In `lib/core/theme/app_colors.dart`, add new named constants: `scaffoldBlack`, `cardFill`, `cardBorder`, `containerBorder`, `navBarFill`, `iconInactive`, `textPrimary`, `textSecondary`, `textHint`, `pressedOverlay`, `focusBorder`, `disabledText` as specified in the design
    - Remove `successGreen`, `warningOrange`, `errorRed`, `restBlue` from default component usage (keep constants for backwards compat but add deprecation comment)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6, 2.8_

  - [x] 1.2 Migrate `AppTextStyles` from Poppins/Inter to Geist font family
    - In `lib/core/theme/app_text_styles.dart`, replace all `GoogleFonts.poppins()` calls with `GoogleFonts.geist()` for heading/title styles
    - Replace all `GoogleFonts.inter()` calls with `GoogleFonts.geist()` for body/label/caption styles
    - Add a new `sectionHeader` style using `GoogleFonts.geistMono()` with fontSize 12, fontWeight w500, letterSpacing 1.5
    - Preserve existing fontSize and letterSpacing values for all migrated styles
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 8.1, 8.3, 8.4_

  - [x] 1.3 Update `ComponentThemes` for dark monochrome card and navigation styles
    - In `lib/core/theme/component_themes.dart`, update `cardThemeDark()` to use `AppColors.cardFill` (0xFF1A1A1A) as color, `AppColors.cardBorder` (0xFF2A2A2A) as border color, elevation 0, border radius 12
    - Update `navigationBarTheme()` to use white for active icons, `AppColors.iconInactive` (0xFF6B6B6B) for inactive icons, and set `labelBehavior: NavigationDestinationLabelBehavior.alwaysHide`
    - Add dark-mode `inputDecorationTheme` variant using grey borders instead of chromatic error colors
    - Define interactive state styles: pressed overlay at 20% white, focused with 1px white border, disabled at 40% opacity
    - _Requirements: 2.3, 2.4, 2.5, 2.8, 7.4, 7.5, 9.1, 9.2, 9.3, 9.4_

  - [x] 1.4 Update `AppTheme` to wire new dark theme together
    - In `lib/core/theme/app_theme.dart`, ensure the dark ThemeData uses `AppColors.scaffoldBlack` as scaffoldBackgroundColor, references the updated text theme, card theme, and navigation bar theme
    - Ensure ColorScheme.dark() uses the correct surface and background values
    - _Requirements: 2.1, 2.2, 2.5, 2.6_

  - [x] 1.5 Write property test: dark theme colors are achromatic
    - **Property 1: Dark theme colors are achromatic**
    - Create `test/core/theme/dark_theme_greyscale_test.dart`
    - Extract all colors from dark theme's ColorScheme, CardTheme, NavigationBarTheme, AppBarTheme, InputDecorationTheme and assert R == G == B for each
    - **Validates: Requirements 2.6**

- [x] 2. Create shared reusable widgets
  - [x] 2.1 Implement `SectionHeader` widget
    - Create `lib/shared/widgets/section_header.dart`
    - Stateless widget accepting `title` (String) and optional `trailingLabel` (String?)
    - Renders title in `AppTextStyles.sectionHeader` uppercased, trailing label at 0.5 opacity
    - Uses Row with MainAxisAlignment.spaceBetween
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [x] 2.2 Implement `EdgeFadeGradient` widget
    - Create `lib/shared/widgets/edge_fade_gradient.dart`
    - Stateless widget accepting `isTop` (bool) and `height` (double, default 32)
    - Wraps a Container with LinearGradient in an IgnorePointer to avoid intercepting touches
    - Top gradient: scaffoldBlack → transparent; Bottom gradient: transparent → scaffoldBlack
    - _Requirements: 10.5, 10.6, 10.7_

  - [x] 2.3 Implement `BodySilhouetteWidget` with CustomPainter
    - Create `lib/shared/widgets/body_silhouette_widget.dart`
    - Stateless widget accepting `targetedMuscleGroups` (List<String>) and `height` (double, default 60)
    - Uses CustomPainter to draw grey body outline path
    - Maps muscle group names to normalized (x, y) positions and renders white dots at those locations
    - _Requirements: 3.3, 3.4_

  - [x] 2.4 Write property test: muscle group positions within bounds
    - **Property 9: Muscle group positions are within body outline bounds**
    - Create `test/shared/widgets/body_silhouette_test.dart`
    - For any valid muscle group name from the supported set, verify mapped dot position falls within bounding box
    - **Validates: Requirements 3.4**

  - [x] 2.5 Write unit tests for SectionHeader and EdgeFadeGradient
    - Create `test/shared/widgets/section_header_test.dart` — verify uppercase rendering, trailing label opacity
    - Create `test/shared/widgets/edge_fade_gradient_test.dart` — verify IgnorePointer wrapping, gradient direction
    - _Requirements: 8.1, 8.2, 10.6, 10.7_

- [x] 3. Checkpoint - Ensure theme and shared widgets compile
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement Dashboard calendar grid widget
  - [x] 4.1 Create calendar grid generation utility
    - Create `lib/features/dashboard/utils/calendar_utils.dart`
    - Implement `generateCalendarGrid(int year, int month)` returning a list of day cells (nullable int) with leading empty cells based on first weekday (Monday=1)
    - Implement `DayStatus` enum and `getDayStatus(DateTime date, Set<DateTime> completedDates)` function
    - _Requirements: 4.3, 4.4, 4.5, 4.6_

  - [x] 4.2 Implement `CalendarGridWidget`
    - Create `lib/features/dashboard/widgets/calendar_grid_widget.dart`
    - Renders SectionHeader with "CALENDAR GRID" title and "[TAP A DAY]" trailing label
    - Renders weekday headers row (MO, TU, WE, TH, FR, SA, SU)
    - Renders date grid using GridView with 7 columns
    - White filled circle for completed dates, white outlined circle for today (no workout), no decoration otherwise
    - Emits selected date via callback; defaults to today on first display
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8_

  - [x] 4.3 Write property tests for calendar grid logic
    - **Property 2: Calendar grid contains correct day count for any month**
    - **Property 3: Day status classification is exhaustive and correct**
    - Create `test/features/dashboard/widgets/calendar_grid_test.dart`
    - Generate random year/month, verify cell count; generate random dates + completed set, verify status
    - **Validates: Requirements 4.3, 4.4, 4.5, 4.6**

- [x] 5. Implement Dashboard weekly load chart widget
  - [x] 5.1 Create weekly load calculation utilities
    - Create `lib/features/dashboard/utils/weekly_load_utils.dart`
    - Implement `computeWeekRanges(DateTime referenceDate)` returning four (start, end) DateTime pairs covering Mon–Sun for each of the last 4 weeks
    - Implement `calculateWeeklyVolume(List<WorkoutSession> sessions, DateTime weekStart)` summing sets × reps
    - Implement `computeBarHeights(List<int> volumes, double maxChartHeight)` returning proportional heights (or minimum height if all zero)
    - _Requirements: 5.2, 5.3, 5.6, 5.7_

  - [x] 5.2 Implement `WeeklyLoadChartWidget` using fl_chart
    - Create `lib/features/dashboard/widgets/weekly_load_chart_widget.dart`
    - Renders SectionHeader with "WEEKLY LOAD" title and "[LAST 4]" trailing label
    - Uses `fl_chart` BarChart with 4 bars labeled W1–W4
    - White fill for bars with data, grey fill for zero-data bars
    - Displays numeric volume value above each bar
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

  - [x] 5.3 Write property tests for weekly load logic
    - **Property 4: Four-week ranges are non-overlapping and chronologically ordered**
    - **Property 5: Weekly volume calculation equals sum of sets times reps**
    - **Property 6: Bar height scaling is proportional to maximum volume**
    - Create `test/features/dashboard/widgets/weekly_load_chart_test.dart`
    - Generate random reference dates, verify week ranges; generate random exercise lists, verify volume; generate 4 random volumes, verify bar heights
    - **Validates: Requirements 5.2, 5.3, 5.6, 5.7**

- [x] 6. Implement Dashboard completed sessions widget
  - [x] 6.1 Create date formatting and session display utilities
    - Create `lib/features/dashboard/utils/session_display_utils.dart`
    - Implement `formatDateDisplay(DateTime date)` returning "Month Day, Year" format
    - Implement `formatDuration(int totalSeconds)` returning "{n} min" string
    - _Requirements: 6.2, 6.4_

  - [x] 6.2 Implement `CompletedSessionsWidget`
    - Create `lib/features/dashboard/widgets/completed_sessions_widget.dart`
    - Renders SectionHeader with "COMPLETED SESSIONS" title and "{count} ON DAY" trailing label
    - Displays formatted selected date
    - Shows empty-state message when no sessions exist
    - Shows session summary rows (workout name + duration) when sessions exist
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [x] 6.3 Write property tests for date and duration formatting
    - **Property 7: Date display formatting round-trip**
    - **Property 8: Duration formatting correctness**
    - Create `test/features/dashboard/widgets/completed_sessions_test.dart`
    - Generate random DateTimes, verify format pattern; generate random second values, verify "{n} min" format
    - **Validates: Requirements 6.2, 6.4**

- [x] 7. Checkpoint - Ensure dashboard widgets compile and pass tests
  - Ensure all tests pass, ask the user if questions arise.

- [x] 8. Refactor Dashboard screen with new sub-widgets and edge fades
  - [x] 8.1 Refactor `DashboardScreen` to compose CalendarGrid, WeeklyLoadChart, CompletedSessions
    - In `lib/features/dashboard/screens/dashboard_screen.dart`, replace existing content with a Stack containing:
      - Scrollable column with CalendarGridWidget, WeeklyLoadChartWidget, CompletedSessionsWidget
      - EdgeFadeGradient at top and bottom positioned above scroll content
    - Wire selected date state from CalendarGridWidget to CompletedSessionsWidget
    - Use `AppSpacing` constants for vertical spacing between sections (8–16dp)
    - _Requirements: 4.7, 4.8, 6.1, 10.1, 10.2, 11.3_

  - [x] 8.2 Write widget test for DashboardScreen composition
    - Create `test/features/dashboard/screens/dashboard_screen_test.dart`
    - Verify CalendarGrid, WeeklyLoadChart, CompletedSessions widgets are present
    - Verify edge fades are rendered at top and bottom
    - _Requirements: 10.1, 10.2, 11.3_

- [x] 9. Refactor Exercise Library screen
  - [x] 9.1 Implement `ExerciseRow` widget
    - Create `lib/features/exercise_library/widgets/exercise_row.dart`
    - Renders exercise name in bold Geist on the left
    - Renders subtitle "{muscle_group} · {equipment_type}" at 60–70% white opacity below name
    - Renders BodySilhouetteWidget on the right, vertically centered
    - Row separated by thin divider (0.5–1px in subtle grey)
    - Tapping navigates to exercise detail screen
    - No colored badges or Material card wrappers
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7_

  - [x] 9.2 Refactor `ExerciseListScreen` to use ExerciseRow and edge fades
    - In `lib/features/exercise_library/screens/exercise_list_screen.dart`, replace existing list item rendering with ExerciseRow widget
    - Add EdgeFadeGradient at top (below search/filter if present) and bottom (above nav bar)
    - Use `AppSpacing` constants for vertical padding between items (4–12dp)
    - _Requirements: 3.1, 3.5, 3.6, 10.3, 10.4, 11.2_

  - [x] 9.3 Write widget test for ExerciseRow
    - Create `test/features/exercise_library/widgets/exercise_row_test.dart`
    - Verify text content, subtitle opacity, body silhouette presence, divider rendering, tap navigation
    - _Requirements: 3.1, 3.2, 3.3, 3.5, 3.7_

- [x] 10. Implement floating pill bottom navigation bar
  - [x] 10.1 Create `FloatingPillNavBar` widget
    - Create `lib/shared/widgets/floating_pill_nav_bar.dart`
    - Pill-shaped container: corner radius 28dp, height 56dp, positioned 16dp above screen bottom with 60dp horizontal margin
    - Opaque dark fill 0xFF424242, visually distinct from jet black background
    - Five icon destinations in order: grid (dashboard), dumbbell (workout), calendar, chat (community), search
    - Active icon in white, inactive in grey (0xFF6B6B6B)
    - No text labels, minimum 48×48dp touch targets
    - Emits selected index on tap
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 11.4_

  - [x] 10.2 Integrate `FloatingPillNavBar` into app shell
    - In `lib/core/router/app_router.dart`, replace existing navigation bar usage with FloatingPillNavBar in the shell screen builder
    - Wire the 5 destinations to correct routes (dashboard, workout, calendar, community, search)
    - Ensure body content is positioned to avoid overlap with the floating nav bar (add bottom padding)
    - _Requirements: 7.3, 7.7_

  - [x] 10.3 Write widget test for FloatingPillNavBar
    - Create `test/shared/widgets/floating_pill_nav_bar_test.dart`
    - Verify 5 icons render, active/inactive colors, tap callback, no text labels, pill shape dimensions
    - _Requirements: 7.1, 7.3, 7.4, 7.5, 7.6_

- [x] 11. Final checkpoint - Ensure all tests pass and app compiles
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The `AppSpacing` constants already satisfy Requirement 11.1 (xs=4, sm=8, md=16, lg=24)
- No new packages are needed — `google_fonts`, `fl_chart`, and `glados` are already in pubspec.yaml

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["1.3", "1.4", "2.1", "2.2"] },
    { "id": 2, "tasks": ["1.5", "2.3", "2.5"] },
    { "id": 3, "tasks": ["2.4", "4.1", "5.1", "6.1"] },
    { "id": 4, "tasks": ["4.2", "5.2", "6.2"] },
    { "id": 5, "tasks": ["4.3", "5.3", "6.3"] },
    { "id": 6, "tasks": ["8.1", "9.1", "10.1"] },
    { "id": 7, "tasks": ["8.2", "9.2", "10.2"] },
    { "id": 8, "tasks": ["9.3", "10.3"] }
  ]
}
```
