import 'package:flutter/material.dart';

/// A 404 "Page Not Found" screen with a button to navigate back to the dashboard.
///
/// Used as the router's error builder for undefined routes.
class PageNotFoundScreen extends StatelessWidget {
  const PageNotFoundScreen({super.key, this.onGoToDashboard});

  /// Optional callback for navigating to the dashboard.
  ///
  /// If not provided, the widget uses `Navigator.of(context)` to pop or
  /// push a replacement route. Once go_router is wired up, pass a callback
  /// that calls `context.go('/dashboard')`.
  final VoidCallback? onGoToDashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 80,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 24),
              Text(
                'Page Not Found',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The page you are looking for does not exist.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: onGoToDashboard ??
                    () {
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/', (_) => false);
                    },
                icon: const Icon(Icons.dashboard),
                label: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
