import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';

/// Screen for managing notification preferences.
///
/// Displays toggle switches for each notification category.
/// All toggles default to enabled. Changes are persisted via SharedPreferences.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final notifier = ref.read(notificationSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Workout Reminders'),
            subtitle: const Text('Get reminded about scheduled workouts'),
            value: settings.workoutReminders,
            onChanged: (value) =>
                notifier.setNotificationPreference('workoutReminders', value),
          ),
          SwitchListTile(
            title: const Text('Community Updates'),
            subtitle: const Text('Stay updated on community activity'),
            value: settings.communityUpdates,
            onChanged: (value) =>
                notifier.setNotificationPreference('communityUpdates', value),
          ),
          SwitchListTile(
            title: const Text('Achievement Alerts'),
            subtitle: const Text('Celebrate when you reach milestones'),
            value: settings.achievementAlerts,
            onChanged: (value) =>
                notifier.setNotificationPreference('achievementAlerts', value),
          ),
          SwitchListTile(
            title: const Text('Consultation Reminders'),
            subtitle: const Text('Reminders for upcoming trainer sessions'),
            value: settings.consultationReminders,
            onChanged: (value) => notifier.setNotificationPreference(
                'consultationReminders', value),
          ),
        ],
      ),
    );
  }
}
