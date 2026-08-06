import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/connectivity_monitor.dart';
import '../../core/network/connectivity_provider.dart';

/// A persistent banner that appears when the device is offline.
///
/// Place this widget above or below the main content in a [Column] or
/// [Stack]. It watches [connectivityStatusProvider] and automatically
/// shows/hides with an animated size transition.
class OfflineIndicator extends ConsumerWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityStatusProvider);
    final isOffline = status == ConnectivityStatus.offline;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: isOffline ? _buildBanner(context) : const SizedBox.shrink(),
    );
  }

  Widget _buildBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.orange.shade800,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'You are offline',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
