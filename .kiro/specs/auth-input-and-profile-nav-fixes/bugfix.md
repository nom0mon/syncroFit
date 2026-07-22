# Bugfix Requirements Document

## Introduction

Three UI bugs in the SyncroFit Flutter app affect usability of the authentication screens, the Edit Profile module, and the navigation bar:

1. **Auth TextFields missing visible placeholders and disappearing on focus** — The Username and Password text fields on the Login and Register screens do not display placeholder text when unfocused, and the text box visually disappears (loses its border/outline) when the user taps into it to type.

2. **Edit Profile screen missing back/return button** — The Edit Profile screen, accessed from Settings, has no back button to return the user to the previous screen. This is caused by using `context.go()` navigation which replaces the route stack instead of pushing, so Flutter's AppBar does not automatically render a back button.

3. **Search module should be removed from navigation** — The Search tab/destination was added to the bottom navigation bar but should be completely removed. The navigation bar should revert to 4 destinations (Dashboard, Workout, Calendar, Community) without any Search icon or route.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the Login screen is displayed with the E-mail and Password TextFormFields unfocused THEN the system does not display visible placeholder text within the fields

1.2 WHEN the Register screen is displayed with the E-mail, Password, Confirm Password, and Email Address TextFormFields unfocused THEN the system does not display visible placeholder text within the fields

1.3 WHEN the user taps into (focuses) a TextFormField on the Login or Register screen THEN the system causes the text box border to visually disappear or become invisible

1.4 WHEN the user navigates to the Edit Profile screen from Settings THEN the system does not display a back/return button in the AppBar to navigate back

1.5 WHEN the bottom navigation bar is displayed THEN the system renders a Search icon as the 5th destination, which should not exist

### Expected Behavior (Correct)

2.1 WHEN the Login screen is displayed with the E-mail and Password TextFormFields unfocused THEN the system SHALL display grey placeholder text (hint) inside each field indicating the expected input

2.2 WHEN the Register screen is displayed with the E-mail, Password, Confirm Password, and Email Address TextFormFields unfocused THEN the system SHALL display grey placeholder text (hint) inside each field indicating the expected input

2.3 WHEN the user taps into (focuses) a TextFormField on the Login or Register screen THEN the system SHALL maintain the visible text box border with a focused-state style (darker border) and the placeholder text SHALL disappear only when the user begins typing

2.4 WHEN the user navigates to the Edit Profile screen from Settings THEN the system SHALL display a back arrow button in the AppBar leading position that returns the user to the Settings screen when tapped

2.5 WHEN the bottom navigation bar is displayed THEN the system SHALL render exactly 4 icon destinations (Dashboard, Workout, Calendar, Community) with no Search destination, and the Search route and branch SHALL be completely removed from the router configuration

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the user types valid text into the Login screen fields and submits THEN the system SHALL CONTINUE TO authenticate the user and navigate to the dashboard

3.2 WHEN the user types valid text into the Register screen fields and submits THEN the system SHALL CONTINUE TO register the user and navigate to profile setup

3.3 WHEN the user is on the Edit Profile screen and submits valid profile data THEN the system SHALL CONTINUE TO update the profile and display a success confirmation

3.4 WHEN the user interacts with TextFormFields on other screens (e.g., Profile Setup, Settings) THEN the system SHALL CONTINUE TO display placeholders and borders correctly as they currently do

3.5 WHEN the user navigates between other Settings sub-screens (Notification Settings, Change Password) THEN the system SHALL CONTINUE TO display back buttons and navigate correctly

3.6 WHEN the user taps the Dashboard, Workout, Calendar, or Community navigation destinations THEN the system SHALL CONTINUE TO navigate to the correct screen and display the active icon state
