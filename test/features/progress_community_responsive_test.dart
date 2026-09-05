import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/features/community/providers/community_provider.dart';
import 'package:synchrofit/features/community/screens/feed_screen.dart';
import 'package:synchrofit/features/community/screens/post_detail_screen.dart';
import 'package:synchrofit/features/progress/providers/progress_provider.dart';
import 'package:synchrofit/features/progress/screens/progress_summary_screen.dart';
import 'package:synchrofit/features/progress/utils/bmi_utils.dart';
import 'package:synchrofit/shared/models/models.dart';

import '../support/responsive_test_harness.dart';

void main() {
  final longName = List.filled(18, 'VeryLongMemberName').join(' ');
  final longBody = List.filled(
    45,
    'A detailed community update that must wrap safely on Android screens.',
  ).join(' ');
  final longComment = List.filled(
    30,
    'A thoughtful comment with enough detail to require multiple lines.',
  ).join(' ');

  final comment = Comment(
    id: 'comment-1',
    postId: 'post-1',
    authorName: longName,
    text: longComment,
    timestamp: DateTime(2025, 1, 2, 12),
  );
  final post = Post(
    id: 'post-1',
    authorName: longName,
    content: longBody,
    timestamp: DateTime(2025, 1, 2, 12),
    likeCount: 123456,
    isLikedByCurrentUser: true,
    comments: [comment],
  );

  group('ProgressSummaryScreen responsive remediation', () {
    const progressState = ProgressState(
      totalWorkouts: 123456,
      totalDurationSeconds: 987654,
      plannedThisWeek: 12,
      completedThisWeek: 4,
      weeklyStats: [
        WeeklyStat(weekLabel: '2025-W01', workoutsCompleted: 2),
        WeeklyStat(weekLabel: '2025-W02', workoutsCompleted: 3),
        WeeklyStat(weekLabel: '2025-W03', workoutsCompleted: 4),
        WeeklyStat(weekLabel: '2025-W04', workoutsCompleted: 1),
      ],
    );

    for (final configuration
        in ResponsiveTestConfiguration.requiredConfigurations) {
      testWidgets('adapts at ${configuration.name}', (tester) async {
        await tester.pumpResponsiveWidget(
          ProviderScope(
            overrides: [
              progressProvider.overrideWith(
                () => _FakeProgressNotifier(progressState),
              ),
              bmiProvider.overrideWithValue(
                const AsyncValue.data(
                  BmiResult(value: 22.857, category: BmiCategory.healthy),
                ),
              ),
            ],
            child: const ProgressSummaryScreen(
              photosSection: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Future progress photo grid'),
                ),
              ),
            ),
          ),
          configuration: configuration,
          settle: true,
        );

        expect(
          find.byKey(const Key('progress-photos-integration-point')),
          findsOneWidget,
        );
        expect(find.text('Future progress photo grid'), findsOneWidget);
        expect(find.text('22.9'), findsOneWidget);
        expect(find.text('Healthy'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'simplifies compact chart labels and preserves full tablet labels',
        (tester) async {
      Widget screen() => ProviderScope(
            overrides: [
              progressProvider.overrideWith(
                () => _FakeProgressNotifier(progressState),
              ),
              bmiProvider.overrideWithValue(
                const AsyncValue.data(
                  BmiResult(value: 22.857, category: BmiCategory.healthy),
                ),
              ),
            ],
            child: const ProgressSummaryScreen(),
          );

      await tester.pumpResponsiveWidget(
        screen(),
        configuration: ResponsiveTestConfiguration.compactPhone,
        settle: true,
      );
      expect(find.text('W01'), findsOneWidget);
      expect(find.text('2025-W01'), findsNothing);

      await tester.pumpResponsiveWidget(
        screen(),
        configuration: ResponsiveTestConfiguration.tablet,
        settle: true,
      );
      expect(find.text('2025-W01'), findsOneWidget);
    });

    testWidgets('prompts for profile when BMI measurements are unavailable',
        (tester) async {
      await tester.pumpResponsiveWidget(
        ProviderScope(
          overrides: [
            progressProvider.overrideWith(
              () => _FakeProgressNotifier(progressState),
            ),
            bmiProvider.overrideWithValue(const AsyncValue.data(null)),
          ],
          child: const ProgressSummaryScreen(),
        ),
        configuration: ResponsiveTestConfiguration.compactPhone,
        settle: true,
      );

      expect(find.byKey(const Key('bmi-profile-required')), findsOneWidget);
      expect(find.text('Set Up Profile'), findsOneWidget);
      expect(find.text('22.9'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Community responsive remediation', () {
    for (final configuration
        in ResponsiveTestConfiguration.requiredConfigurations) {
      testWidgets('feed adapts at ${configuration.name}', (tester) async {
        await tester.pumpResponsiveWidget(
          ProviderScope(
            overrides: [
              communityProvider.overrideWith(
                () => _FakeCommunityNotifier([post]),
              ),
            ],
            child: const FeedScreen(
              composer: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Future post composer'),
                ),
              ),
            ),
          ),
          configuration: configuration,
          settle: true,
        );

        expect(
          find.byKey(const Key('community-composer-integration-point')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('community-post-post-1')),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('post detail adapts at ${configuration.name}',
          (tester) async {
        await tester.pumpResponsiveWidget(
          ProviderScope(
            overrides: [
              communityProvider.overrideWith(
                () => _FakeCommunityNotifier([post]),
              ),
            ],
            child: const PostDetailScreen(postId: 'post-1'),
          ),
          configuration: configuration,
          settle: true,
          mustRemainVisible: [
            find.byKey(const Key('community-comment-field')),
            find.byKey(const Key('community-submit-comment')),
          ],
        );

        expect(find.text(longName), findsAtLeastNWidgets(1));
        await tester.scrollUntilVisible(
          find.text(longComment),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(find.text(longComment), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'empty and unavailable states retain responsive integration points',
        (tester) async {
      await tester.pumpResponsiveWidget(
        ProviderScope(
          overrides: [
            communityProvider.overrideWith(
              () => _FakeCommunityNotifier(const []),
            ),
          ],
          child: const FeedScreen(
            composer: Text('Future post composer'),
          ),
        ),
        configuration: ResponsiveTestConfiguration.largeText,
        settle: true,
      );
      expect(find.text('No posts yet. Be the first to share!'), findsOneWidget);
      expect(
        find.byKey(const Key('community-composer-integration-point')),
        findsOneWidget,
      );

      await tester.pumpResponsiveWidget(
        ProviderScope(
          overrides: [
            communityProvider.overrideWith(
              () => _FakeCommunityNotifier(const []),
            ),
          ],
          child: const PostDetailScreen(postId: 'missing'),
        ),
        configuration: ResponsiveTestConfiguration.compactPhone,
        settle: true,
      );
      expect(find.text('This post is unavailable.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long error state is safe at 200 percent text scale',
        (tester) async {
      await tester.pumpResponsiveWidget(
        ProviderScope(
          overrides: [
            communityProvider.overrideWith(_ErrorCommunityNotifier.new),
          ],
          child: const FeedScreen(),
        ),
        configuration: ResponsiveTestConfiguration.largeText,
        settle: true,
      );

      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

class _FakeProgressNotifier extends ProgressNotifier {
  _FakeProgressNotifier(this.progressState);

  final ProgressState progressState;

  @override
  Future<ProgressState> build() async => progressState;
}

class _FakeCommunityNotifier extends CommunityNotifier {
  _FakeCommunityNotifier(this.posts);

  final List<Post> posts;

  @override
  Future<CommunityState> build() async => CommunityState(posts: posts);
}

class _ErrorCommunityNotifier extends CommunityNotifier {
  @override
  Future<CommunityState> build() async {
    throw StateError(
      List.filled(20, 'A detailed community loading failure').join(' '),
    );
  }
}
