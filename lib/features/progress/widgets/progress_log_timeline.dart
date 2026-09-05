import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/token_storage.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/models/models.dart';
import '../providers/progress_log_provider.dart';
import '../utils/progress_log_grouping.dart';

class ProgressLogTimeline extends ConsumerWidget {
  const ProgressLogTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(progressLogsProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Progress Logs', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.sm),
      logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: OutlinedButton(
            onPressed: () => ref.invalidate(progressLogsProvider),
            child: const Text('Retry progress logs'),
          ),
        ),
        data: (items) => items.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: Text('No progress logs yet.')),
              )
            : _GroupedLogs(logs: items),
      ),
    ]);
  }
}

class _GroupedLogs extends ConsumerWidget {
  const _GroupedLogs({required this.logs});
  final List<ProgressLog> logs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = groupProgressLogsByMonth(logs);
    return Column(
      children: groups.entries.map((entry) {
        final first = entry.value.first.createdAt.toLocal();
        final heading = '${_months[first.month - 1]} ${first.year}';
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(heading, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            ...entry.value.map((log) => Card(
                  child: InkWell(
                    onTap: () => _showDetail(context, ref, log),
                    child: Row(children: [
                      SizedBox(width: 112, height: 96, child: _PrivateImage(log.imageUrl)),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(log.title, style: Theme.of(context).textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text('${log.weightKg.toStringAsFixed(1)} kg'),
                            Text('${log.createdAt.toLocal().day} $heading', style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                )),
          ]),
        );
      }).toList(),
    );
  }

  Future<void> _showDetail(BuildContext context, WidgetRef ref, ProgressLog log) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(log.title),
        content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(aspectRatio: 1, child: _PrivateImage(log.imageUrl)),
          const SizedBox(height: AppSpacing.sm),
          Text(log.description),
          const SizedBox(height: AppSpacing.sm),
          Text('${log.weightKg.toStringAsFixed(1)} kg'),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (confirmContext) => AlertDialog(
                      title: const Text('Delete progress log?'),
                      content: const Text('This permanently removes the log and its private photo.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(confirmContext, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(confirmContext, true), child: const Text('Delete')),
                      ],
                    ),
                  ) ??
                  false;
              if (!confirmed) return;
              final error = await ref.read(progressLogsProvider.notifier).delete(log.id);
              if (context.mounted && error == null) Navigator.pop(context);
              if (context.mounted && error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _PrivateImage extends StatelessWidget {
  const _PrivateImage(this.url);
  final String url;

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
        future: TokenStorage().getToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return Image.network(
            url,
            headers: snapshot.data == null ? null : {'Authorization': 'Bearer ${snapshot.data}'},
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined)),
          );
        },
      );
}

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
