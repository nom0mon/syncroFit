import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/exercise_provider.dart';
import '../widgets/exercise_library_tab.dart';

/// Displays the exercise library as a standalone routed screen.
///
/// The released tab and this legacy standalone entry share the same adaptive
/// library content so responsive behavior cannot drift between them.
class ExerciseListScreen extends ConsumerWidget {
  const ExerciseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(exerciseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Library'),
      ),
      body: state.isLoading
          ? const LoadingIndicator()
          : state.errorMessage != null
              ? ErrorDisplay(
                  message: state.errorMessage!,
                  onRetry: () =>
                      ref.read(exerciseProvider.notifier).loadExercises(),
                )
              : const ExerciseLibraryTab(showStatusStates: false),
    );
  }
}
