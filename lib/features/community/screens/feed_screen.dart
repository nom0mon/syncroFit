import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/edge_fade_gradient.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../providers/community_provider.dart';

/// Displays a responsive, constrained list of community posts.
///
/// [composer] reserves the feed's responsive integration point for the post
/// composer without coupling this remediation task to its later data flow.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({
    super.key,
    this.composer,
  });

  final Widget? composer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communityAsync = ref.watch(communityProvider);
    final effectiveComposer = composer ?? const _PostComposer();

    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      body: SafeArea(
        top: false,
        child: communityAsync.when(
          loading: () => const _CommunityStatePage(
            child: LoadingIndicator(),
          ),
          error: (error, _) => _CommunityStatePage(
            child: ErrorDisplay(
              message: error.toString(),
              onRetry: () => ref.invalidate(communityProvider),
            ),
          ),
          data: (state) {
            if (state.errorMessage != null) {
              return _CommunityStatePage(
                child: ErrorDisplay(
                  message: state.errorMessage!,
                  onRetry: () => ref.invalidate(communityProvider),
                ),
              );
            }

            if (state.posts.isEmpty) {
              return _EmptyFeed(composer: effectiveComposer);
            }

            return _FeedList(posts: state.posts, composer: effectiveComposer);
          },
        ),
      ),
    );
  }
}

class _CommunityStatePage extends StatelessWidget {
  const _CommunityStatePage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ResponsiveConstrainedPage(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({this.composer});

  final Widget? composer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        if (composer != null) ...[
          ResponsiveConstrainedPage(
            child: KeyedSubtree(
              key: const Key('community-composer-integration-point'),
              child: composer!,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const ResponsiveConstrainedPage(
          child: EmptyState(
            icon: Icons.forum_outlined,
            message: 'No posts yet. Be the first to share!',
          ),
        ),
      ],
    );
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList({
    required this.posts,
    this.composer,
  });

  final List<Post> posts;
  final Widget? composer;

  @override
  Widget build(BuildContext context) {
    final leadingItems = composer == null ? 0 : 1;

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.xxl,
          ),
          itemCount: posts.length + leadingItems,
          itemBuilder: (context, index) {
            if (composer != null && index == 0) {
              return ResponsiveConstrainedPage(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: KeyedSubtree(
                    key: const Key('community-composer-integration-point'),
                    child: composer!,
                  ),
                ),
              );
            }

            final postIndex = index - leadingItems;
            return ResponsiveConstrainedPage(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _PostCard(post: posts[postIndex]),
              ),
            );
          },
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: EdgeFadeGradient(isTop: true),
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: EdgeFadeGradient(isTop: false),
        ),
      ],
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final content = CommunityNotifier.truncateContent(post.content);
    final cardPadding = ResponsiveStandards.cardPaddingFor(
      MediaQuery.sizeOf(context).width,
    );

    return Card(
      key: ValueKey('community-post-${post.id}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/community/post/${post.id}'),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.authorName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                content,
                style: theme.textTheme.bodyMedium,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    label: post.isLikedByCurrentUser ? 'Unlike post' : 'Like post',
                    button: true,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref.read(communityProvider.notifier).toggleLike(post.id),
                      icon: Icon(
                        post.isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                        color: post.isLikedByCurrentUser
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text('${post.likeCount}'),
                  _PostMetric(
                    icon: Icons.comment_outlined,
                    value: '${post.commentCount}',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  Text(
                    formatRelativeTimestamp(post.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostComposer extends ConsumerStatefulWidget {
  const _PostComposer();

  @override
  ConsumerState<_PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends ConsumerState<_PostComposer> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    final error = await ref.read(communityProvider.notifier).createPost(_controller.text);
    if (!mounted) return;
    setState(() { _submitting = false; _error = error; });
    if (error == null) _controller.clear();
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('community-post-field'),
                controller: _controller,
                enabled: !_submitting,
                minLines: 2,
                maxLines: 6,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: 'Share with the community',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('community-submit-post'),
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: const Text('Post'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _PostMetric extends StatelessWidget {
  const _PostMetric({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(value, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
