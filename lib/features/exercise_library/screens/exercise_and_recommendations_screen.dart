import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/exercise_library_tab.dart';
import '../widgets/recommendations_tab.dart';

/// A tabbed screen combining the Exercise Library and Recommendations views.
///
/// Uses [DefaultTabController] with two tabs:
/// - Tab 0: Exercise Library (filter/search UI)
/// - Tab 1: Recommendations (workout scheduler + daily plan)
///
/// Each tab uses [AutomaticKeepAliveClientMixin] to preserve scroll position
/// and state across tab switches.
///
/// Validates: Requirements 8.1, 8.4
class ExerciseAndRecommendationsScreen extends ConsumerStatefulWidget {
  const ExerciseAndRecommendationsScreen({super.key});

  @override
  ConsumerState<ExerciseAndRecommendationsScreen> createState() =>
      _ExerciseAndRecommendationsScreenState();
}

class _ExerciseAndRecommendationsScreenState
    extends ConsumerState<ExerciseAndRecommendationsScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exercises'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Exercise Library'),
              Tab(text: 'Recommendations'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ExerciseLibraryTab(),
            RecommendationsTab(),
          ],
        ),
      ),
    );
  }
}
