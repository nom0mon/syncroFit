import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/community_provider.dart';

/// Displays a scrollable list of community posts.
///
/// Each post card shows the author name, truncated content (150 chars max),
/// like count, comment count, and a relative timestamp.
///
/// Tapping a post navigates to the [PostDetailScreen].
///
/// Validates: Requirements 10.1, 10.2
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communityAsync = ref.watch(communityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
      ),
      body: communityAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorDisplay(
          message: error.toString(),
          onRetry: () => ref.invalidate(communityProvider),
        ),
        data: (state) {
          if (state.errorMessage != null) {
            return ErrorDisplay(
              message: state.errorMessage!,
              onRetry: () => ref.invalidate(communityProvider),
            );
          }

          if (state.posts.isEmpty) {
            return const EmptyState(
              icon: Icons.forum_outlined,
              message: 'No posts yet. Be the first to share!',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.posts.length,
            itemBuilder: (context, index) {
              final post = state.posts[index];
              final truncatedContent =
                  CommunityNotifier.truncateContent(post.content);

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  onTap: () {
                    context.go('/community/post/${post.id}');
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author name
                        Text(
                          post.authorName,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: AppSpacing.xs),

                        // Truncated content
                        Text(
                          truncatedContent,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Like count, comment count, timestamp
                        Row(
                          children: [
                            Icon(
                              post.isLikedByCurrentUser
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 16,
                              color: post.isLikedByCurrentUser
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '${post.likeCount}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Icon(
                              Icons.comment_outlined,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '${post.comments.length}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const Spacer(),
                            Text(
                              formatRelativeTimestamp(post.timestamp),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
