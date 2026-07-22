# Bugfix Requirements Document

## Introduction

This bugfix addresses multiple related UI issues in the SyncroFit app:

1. **Light mode fade effects render with dark colors** — The `EdgeFadeGradient` widget hardcodes `AppColors.scaffoldBlack` (pure black `#000000`) for its gradient color regardless of the active theme. When the app is in light mode, these fade overlays appear as dark bands against a light background on ALL screens that use the widget (Dashboard, Exercise Library, etc.), making them visually jarring and incorrect.

2. **Missing fade effects on Progress and Community screens** — The Progress and Community module screens do not have the `EdgeFadeGradient` overlays at all, resulting in an inconsistent UX compared to other scrollable screens.

3. **System back button exits app on all settings sub-screens** — On ALL settings sub-screens (Edit Profile, Notifications, Change Password, Trainers, etc.), pressing the system/hardware back button exits the application entirely instead of navigating back to the Settings screen.

4. **Edit Profile screen missing visible back button** — The Edit Profile screen does not display a visible back arrow button in the top-left corner of its AppBar to allow the user to return to the previous screen.

5. **Pixel overflow in light mode** — There are pixel overflow issues visible in light mode where UI elements extend beyond their intended boundaries.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the app is in light mode AND any screen uses the `EdgeFadeGradient` widget THEN the system renders the gradient fade using hardcoded black (`AppColors.scaffoldBlack`) which appears as a dark overlay against the light background

1.2 WHEN the app is in light mode AND the user scrolls content on the Dashboard screen THEN the system displays black fade bands at the top and bottom edges that obscure content and clash with the light theme

1.3 WHEN the app is in light mode AND the user scrolls content on the Exercise Library screen THEN the system displays black fade bands at the top and bottom edges that clash with the light theme

1.4 WHEN the user navigates to the Progress Summary screen THEN the system does not display any edge fade gradient overlays on the scrollable content

1.5 WHEN the user navigates to the Community screen THEN the system does not display any edge fade gradient overlays on the scrollable content

1.6 WHEN the user is on any settings sub-screen (Edit Profile, Notifications, Change Password, Trainers) AND presses the system/hardware back button THEN the system exits the application entirely instead of navigating back to the Settings screen

1.7 WHEN the user is on the Edit Profile screen THEN the system does not display a visible back/return button in the top-left corner of the AppBar

1.8 WHEN the app is in light mode THEN the system displays pixel overflow where UI elements extend beyond their intended layout boundaries

### Expected Behavior (Correct)

2.1 WHEN the app is in light mode AND any screen uses the `EdgeFadeGradient` widget THEN the system SHALL render the gradient fade using the current theme's scaffold background color (white/light for light mode, black for dark mode)

2.2 WHEN the app is in light mode AND the user scrolls content on the Dashboard screen THEN the system SHALL display light-colored fade bands at the top and bottom edges that blend naturally with the light theme background

2.3 WHEN the app is in light mode AND the user scrolls content on the Exercise Library screen THEN the system SHALL display light-colored fade bands at the top and bottom edges that blend naturally with the light theme background

2.4 WHEN the user navigates to the Progress Summary screen THEN the system SHALL display edge fade gradient overlays at the top and bottom of the scrollable content, consistent with other module screens

2.5 WHEN the user navigates to the Community screen THEN the system SHALL display edge fade gradient overlays at the top and bottom of the scrollable content, consistent with other module screens

2.6 WHEN the user is on any settings sub-screen AND presses the system/hardware back button THEN the system SHALL navigate back to the Settings screen without exiting the application

2.7 WHEN the user is on the Edit Profile screen THEN the system SHALL display a visible back button (arrow icon) in the top-left corner of the AppBar that navigates back to the previous screen when tapped

2.8 WHEN the app is in light mode THEN the system SHALL render all UI elements within their intended layout boundaries without pixel overflow

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the app is in dark mode AND any screen uses the `EdgeFadeGradient` widget THEN the system SHALL CONTINUE TO render the gradient fade using a black color that blends with the dark scaffold background

3.2 WHEN the app is in dark mode AND the user scrolls content on any module screen THEN the system SHALL CONTINUE TO display dark fade bands at the top and bottom edges that blend with the dark theme

3.3 WHEN the user is on a settings sub-screen AND navigates back using the visible AppBar back button THEN the system SHALL CONTINUE TO navigate back to the Settings screen correctly

3.4 WHEN the user is on the Edit Profile screen AND submits a profile update THEN the system SHALL CONTINUE TO save the profile and show confirmation feedback as before

3.5 WHEN the app is in dark mode THEN the system SHALL CONTINUE TO render all UI elements without pixel overflow issues

3.6 WHEN the user navigates between main module screens (Dashboard, Exercises, Progress, Community) via bottom navigation THEN the system SHALL CONTINUE TO switch screens correctly without disruption
