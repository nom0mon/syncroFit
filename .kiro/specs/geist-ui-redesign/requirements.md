# Requirements Document

## Introduction

SyncroFit is undergoing a visual redesign to adopt a modern, minimalistic Geist-inspired aesthetic. The redesign replaces the current Poppins/Inter typography with the Geist font family, enforces a pure dark monochrome color palette (jet black, white, grey), and redesigns core screens (Exercise Library, Dashboard, Bottom Navigation) to match the provided mockup. The goal is a high-contrast, tight-but-breathable UI with no color accents and no Material elevation shadows.

## Glossary

- **Theme_System**: The set of Flutter ThemeData, ColorScheme, TextTheme, and component theme definitions that control the app's visual appearance globally
- **Exercise_Library_Screen**: The screen displaying a scrollable list of exercises with name, muscle group, equipment type, and body silhouette illustration
- **Dashboard_Screen**: The main home screen displaying a calendar grid, weekly load chart, and completed sessions section
- **Bottom_Navigation_Bar**: The floating pill-shaped navigation bar displayed at the bottom of the screen with five icon destinations
- **Calendar_Grid**: A monthly date grid widget showing workout completion status per day
- **Weekly_Load_Chart**: A vertical bar chart showing training volume across the last four weeks
- **Completed_Sessions_Section**: A dashboard area showing workout count for a selected date
- **Body_Silhouette_Widget**: An illustration component displaying a grey body outline with white dots highlighting targeted muscle groups
- **Geist_Font**: The Geist font family used for all text rendering in the redesigned UI
- **Section_Header**: An uppercase, monospaced label used to title dashboard sections (e.g. "CALENDAR GRID", "WEEKLY LOAD")
- **Edge_Fade_Gradient**: A linear gradient overlay at the top or bottom of scrollable content that transitions from transparent to the background color, creating a smooth visual boundary
- **Flutter_App**: The SyncroFit Flutter application as a whole

## Requirements

### Requirement 1: Geist Font Integration

**User Story:** As a developer, I want the app to use the Geist font family exclusively, so that the typography matches the modern minimalistic design mockup.

#### Acceptance Criteria

1. THE Theme_System SHALL render all heading text styles (headlineLarge, headlineMedium, headlineSmall, titleLarge, titleMedium, titleSmall) using Geist_Font with weight variants matching the existing weight assignments (w700 for headlineLarge, w600 for headlineMedium, headlineSmall, and titleLarge, w500 for titleMedium and titleSmall)
2. THE Theme_System SHALL render all body, label, and caption text styles (bodyLarge, bodyMedium, bodySmall, labelLarge, labelMedium, labelSmall, caption) using Geist_Font with weight variants matching the existing weight assignments (w400 for body and caption styles, w500 for label styles)
3. THE Theme_System SHALL replace all references to Poppins and Inter font families with Geist_Font in the app_text_styles.dart file, preserving the existing fontSize and letterSpacing values for each style
4. IF the Geist_Font asset fails to load from the google_fonts package, THEN THE Theme_System SHALL fall back to the platform default sans-serif font without displaying an error to the user

### Requirement 2: Dark Monochrome Theme

**User Story:** As a user, I want a pure dark monochrome theme with high contrast, so that the app has a clean, modern aesthetic without distracting color accents.

#### Acceptance Criteria

1. THE Theme_System SHALL use jet black (0xFF000000) as the scaffold and surface background color in dark mode
2. THE Theme_System SHALL use pure white (0xFFFFFFFF) as the primary text color and use white at 60% to 70% opacity as the secondary and hint text color on dark surfaces
3. THE Theme_System SHALL use grey tones (0xFF1A1A1A through 0xFF3D3D3D) for card fills and container backgrounds
4. THE Theme_System SHALL use subtle grey (0xFF2A2A2A through 0xFF3D3D3D) for card border colors instead of pure white borders
5. THE Theme_System SHALL apply zero elevation to all Card widgets, relying on border-only differentiation
6. THE Theme_System SHALL not include any chromatic (non-greyscale) hue in default component styling within the dark theme, restricting the palette to black, white, and grey values only
7. IF a component requires a functional status indication (error, success, or warning state), THEN THE Theme_System SHALL represent that status using white text with an accompanying descriptive label rather than a chromatic color
8. THE Theme_System SHALL define interactive element states (focused, pressed, disabled) using only white or grey tones — pressed states at 10% to 20% white overlay, focused states with a 1-pixel white or grey border, and disabled states at 30% to 40% white opacity

### Requirement 3: Exercise Library Screen Redesign

**User Story:** As a user, I want to browse exercises in a clean list showing the name, muscle group, equipment type, and a body silhouette highlighting targeted muscles, so that I can quickly identify relevant exercises.

#### Acceptance Criteria

1. THE Exercise_Library_Screen SHALL display each exercise as a row containing the exercise name in bold Geist_Font on the left
2. THE Exercise_Library_Screen SHALL display a subtitle below the exercise name formatted as "{muscle_group} · {equipment_type}" using Geist_Font at 60% to 70% white opacity
3. THE Exercise_Library_Screen SHALL display a Body_Silhouette_Widget on the right side of each exercise row, aligned vertically center with the text content
4. THE Body_Silhouette_Widget SHALL render a grey body outline with white dots positioned at the targeted muscle group locations
5. THE Exercise_Library_Screen SHALL separate each exercise row with a thin horizontal divider line of 0.5 to 1 logical pixel in subtle grey (0xFF2A2A2A to 0xFF3D3D3D)
6. THE Exercise_Library_Screen SHALL not display colored difficulty badges or Material card wrappers around individual exercise items
7. WHEN the user taps an exercise row, THE Exercise_Library_Screen SHALL navigate to the exercise detail screen

### Requirement 4: Dashboard Calendar Grid

**User Story:** As a user, I want to see a monthly calendar grid on the dashboard showing which days I completed workouts, so that I can track my consistency at a glance.

#### Acceptance Criteria

1. THE Calendar_Grid SHALL display a Section_Header with the text "CALENDAR GRID" on the left and "[TAP A DAY]" on the right in uppercase monospaced style
2. THE Calendar_Grid SHALL display weekday headers (MO, TU, WE, TH, FR, SA, SU) in a single row above the date numbers, starting with Monday as the first column
3. THE Calendar_Grid SHALL display date numbers arranged in a 7-column grid representing the current month, leaving cells empty for days before the first and after the last day of the month
4. WHEN a date has a completed workout (including today), THE Calendar_Grid SHALL display that date number inside a white filled circle
5. WHEN a date is today and has no completed workout, THE Calendar_Grid SHALL display that date number inside a white outlined circle
6. WHEN a date has no completed workout and is not today, THE Calendar_Grid SHALL display that date number without any circle decoration
7. WHEN the user taps a date in the Calendar_Grid, THE Dashboard_Screen SHALL update the Completed_Sessions_Section to show data for the selected date
8. WHEN the Calendar_Grid is first displayed, THE Calendar_Grid SHALL select today's date by default and THE Dashboard_Screen SHALL display the Completed_Sessions_Section data for today

### Requirement 5: Dashboard Weekly Load Chart

**User Story:** As a user, I want to see my training volume for the last four weeks as a bar chart, so that I can monitor my workload trends.

#### Acceptance Criteria

1. THE Weekly_Load_Chart SHALL display a Section_Header with the text "WEEKLY LOAD" on the left and "[LAST 4]" on the right in uppercase monospaced style
2. THE Weekly_Load_Chart SHALL display exactly four vertical bars labeled W1, W2, W3, and W4 representing the last four complete or partial calendar weeks in chronological order, where W1 is the oldest week and W4 is the most recent week, and each week is bounded from Monday 00:00 to Sunday 23:59
3. THE Weekly_Load_Chart SHALL display the numeric volume value above each bar, where volume is defined as the sum of (sets completed × reps completed) across all completed exercises in all workout sessions within that week, displayed as a whole number with no unit suffix
4. WHEN a week contains at least one completed workout session, THE Weekly_Load_Chart SHALL render that week's bar in solid white fill
5. IF a week contains zero completed workout sessions, THEN THE Weekly_Load_Chart SHALL render that week's bar in grey fill
6. THE Weekly_Load_Chart SHALL scale bar heights proportionally to the maximum volume value across all four weeks, where the bar with the highest volume occupies the full chart height, and remaining bars are sized as a fraction of the maximum
7. IF all four weeks have a volume value of zero, THEN THE Weekly_Load_Chart SHALL render all four bars at a uniform minimum height with grey fill and display "0" above each bar

### Requirement 6: Dashboard Completed Sessions Section

**User Story:** As a user, I want to see how many workouts I completed on a selected day, so that I can review my daily training history.

#### Acceptance Criteria

1. THE Completed_Sessions_Section SHALL display a Section_Header with the text "COMPLETED SESSIONS" on the left and "{count} ON DAY" on the right, where {count} is the number of completed workout sessions for the selected date
2. THE Completed_Sessions_Section SHALL display the selected date formatted as "Month Day, Year" (e.g. "April 25, 2026") below the section header
3. WHEN no sessions exist for the selected date, THE Completed_Sessions_Section SHALL display the message "No finished workouts landed on this day yet. Pick another date or log a new session."
4. WHEN sessions exist for the selected date, THE Completed_Sessions_Section SHALL display each session as a summary row showing the workout name and total duration formatted as minutes (e.g. "45 min")

### Requirement 7: Floating Pill Bottom Navigation Bar

**User Story:** As a user, I want a floating pill-shaped navigation bar with a glossy opaque finish at the bottom of the screen, so that I can switch between app sections with a modern, minimal navigation pattern.

#### Acceptance Criteria

1. THE Bottom_Navigation_Bar SHALL render as a floating pill-shaped container with a corner radius of 28dp, a height of 56dp, positioned 16dp above the screen bottom edge with 60dp horizontal margin on each side
2. THE Bottom_Navigation_Bar SHALL have an opaque dark fill using color value 0xFF424242, visually distinct from the jet black (0xFF000000) background, maintaining the monochrome aesthetic
3. THE Bottom_Navigation_Bar SHALL display exactly five icon destinations in left-to-right order: dashboard (grid icon), workout (dumbbell icon), calendar, community (chat icon), and search, each with a minimum touch target of 48×48dp
4. WHEN a navigation destination is active, THE Bottom_Navigation_Bar SHALL render that destination icon in white (0xFFFFFFFF)
5. WHEN a navigation destination is inactive, THE Bottom_Navigation_Bar SHALL render that destination icon in grey (0xFF6B6B6B)
6. THE Bottom_Navigation_Bar SHALL not display text labels beneath the icons
7. WHEN the user taps a navigation destination, THE Bottom_Navigation_Bar SHALL switch the displayed content to the corresponding app section and update the active icon state to the tapped destination

### Requirement 8: Section Header Styling

**User Story:** As a developer, I want a reusable section header widget styled with uppercase monospaced text, so that dashboard sections have consistent labeling matching the mockup.

#### Acceptance Criteria

1. THE Section_Header SHALL render the title text in uppercase using a monospaced variant of Geist_Font (Geist Mono)
2. WHERE a right-aligned label is provided, THE Section_Header SHALL render that label in uppercase monospaced style with an opacity between 0.4 and 0.6
3. THE Section_Header SHALL use a font size between 11 and 13 logical pixels for tight, compact labeling
4. THE Section_Header SHALL apply letter spacing between 1.0 and 2.0 logical pixels for readability at small sizes

### Requirement 9: Card and Container Styling

**User Story:** As a user, I want UI cards to have subtle rounded borders with dark fill and no shadows, so that content sections are visually separated without heavy Material chrome.

#### Acceptance Criteria

1. THE Theme_System SHALL style all Card widgets with a border radius of 12 logical pixels
2. THE Theme_System SHALL style all Card widgets in dark mode with a fill color of 0xFF1A1A1A, differentiated from the jet black background by a 1-pixel border in 0xFF2A2A2A
3. THE Theme_System SHALL apply a border width of exactly 1 logical pixel to card outlines in dark mode
4. THE Theme_System SHALL set Card elevation to 0 in dark mode, producing no box shadow
5. WHEN content requires visual grouping without a Card widget, THE Theme_System SHALL provide a Container decoration with identical border radius of 12 logical pixels and a 1-pixel border in 0xFF2A2A2A

### Requirement 10: Screen Edge Fade Effects

**User Story:** As a user, I want smooth fade/shadow gradients at the top and bottom edges of scrollable content, so that the interface has polished start and end points that complement the modern minimal design.

#### Acceptance Criteria

1. THE Dashboard_Screen SHALL display an Edge_Fade_Gradient overlay at the top edge of the scrollable content area, positioned above scrollable content in z-order so that content scrolls beneath it, creating a visual transition from the app bar into the content
2. THE Dashboard_Screen SHALL display an Edge_Fade_Gradient overlay at the bottom edge of the scrollable content area above the Bottom_Navigation_Bar, positioned above scrollable content in z-order so that content scrolls beneath it, creating a visual transition into the navigation
3. THE Exercise_Library_Screen SHALL display an Edge_Fade_Gradient overlay at the top edge of the exercise list, below any search or filter controls
4. THE Exercise_Library_Screen SHALL display an Edge_Fade_Gradient overlay at the bottom edge of the exercise list above the Bottom_Navigation_Bar
5. THE Edge_Fade_Gradient overlays SHALL span between 24 and 48 logical pixels in height
6. THE top Edge_Fade_Gradient SHALL transition from the scaffold background color (jet black) at its topmost pixel to fully transparent at its bottommost pixel, and THE bottom Edge_Fade_Gradient SHALL transition from fully transparent at its topmost pixel to the scaffold background color (jet black) at its bottommost pixel
7. THE Edge_Fade_Gradient overlays SHALL not intercept touch events, allowing the user to tap or scroll content beneath the gradient area

### Requirement 11: Spacing and Layout Density

**User Story:** As a user, I want tight but breathable spacing throughout the UI, so that content is dense without feeling cramped.

#### Acceptance Criteria

1. THE Theme_System SHALL define a spacing scale with at least four named values (xs, sm, md, lg) where the base unit (md) is between 12 and 16 logical pixels and each successive value is larger than the previous
2. THE Exercise_Library_Screen SHALL use vertical padding between 4 and 12 logical pixels between exercise list items, referencing a named Theme_System spacing constant
3. THE Dashboard_Screen SHALL use vertical spacing between 8 and 16 logical pixels between dashboard sections, referencing a named Theme_System spacing constant
4. THE Bottom_Navigation_Bar SHALL maintain internal vertical padding between 4 and 12 logical pixels, referencing a named Theme_System spacing constant
5. WHEN any screen renders list items, cards, or section separators, THE Flutter_App SHALL use only named spacing constants from the Theme_System spacing scale rather than hardcoded numeric values
