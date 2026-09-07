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
import '../widgets/community_photo_gallery.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/repositories/community_repository.dart';

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

            return _FeedList(
              posts: state.posts,
              composer: effectiveComposer,
              hasMore: state.hasMore,
              isLoadingMore: state.isLoadingMore,
              onLoadMore: () => ref.read(communityProvider.notifier).loadMore(),
            );
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
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final List<Post> posts;
  final Widget? composer;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

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
          itemCount: posts.length + leadingItems + (hasMore ? 1 : 0),
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

            if (hasMore && index == posts.length + leadingItems) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: FilledButton(
                    onPressed: isLoadingMore ? null : onLoadMore,
                    child: isLoadingMore
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Load more'),
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
              if (post.media.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                CommunityPhotoGallery(photos: post.media),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Semantics(
                    label:
                        post.isLikedByCurrentUser ? 'Unlike post' : 'Like post',
                    button: true,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref
                          .read(communityProvider.notifier)
                          .toggleLike(post.id),
                      icon: Icon(
                        post.isLikedByCurrentUser
                            ? Icons.favorite
                            : Icons.favorite_border,
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
  final _picker = ImagePicker();
  final List<CommunityPhotoUpload> _photos = [];
  bool _submitting = false;
  String? _error;
  double _uploadProgress = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await ref.read(communityProvider.notifier).createPost(
      _controller.text,
      photos: List.unmodifiable(_photos),
      onProgress: (sent, total) {
        if (mounted && total > 0) {
          setState(() => _uploadProgress = sent / total);
        }
      },
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
    if (error == null) {
      _controller.clear();
      setState(() {
        _photos.clear();
        _uploadProgress = 0;
      });
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final selected = await _picker.pickMultiImage(
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 90,
      );
      if (!mounted || selected.isEmpty) return;
      if (selected.length > 4 - _photos.length) {
        setState(() => _error = 'You can attach up to four photos.');
        return;
      }
      final additions = <CommunityPhotoUpload>[];
      for (final photo in selected) {
        final extension = photo.name.split('.').last.toLowerCase();
        final mime = photo.mimeType?.toLowerCase();
        if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension) &&
            !const {'image/jpeg', 'image/png', 'image/webp'}.contains(mime)) {
          setState(() => _error = 'Choose JPEG, PNG, or WebP photos.');
          return;
        }
        final bytes = await photo.readAsBytes();
        if (bytes.length > 8 * 1024 * 1024) {
          setState(() => _error = 'Each photo must be smaller than 8 MB.');
          return;
        }
        final normalizedExtension =
            const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
                ? extension
                : mime == 'image/png'
                    ? 'png'
                    : mime == 'image/webp'
                        ? 'webp'
                        : 'jpg';
        final filename = const {'jpg', 'jpeg', 'png', 'webp'}
                .contains(extension)
            ? photo.name
            : 'community-photo-${DateTime.now().microsecondsSinceEpoch}.$normalizedExtension';
        additions.add(CommunityPhotoUpload(bytes: bytes, filename: filename));
      }
      setState(() {
        _photos.addAll(additions);
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'The photo picker could not open.');
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_photos.isNotEmpty) ...[
                SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (_, index) => Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_photos[index].bytes,
                            width: 104, height: 104, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: IconButton.filledTonal(
                          tooltip: 'Remove photo',
                          visualDensity: VisualDensity.compact,
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _photos.removeAt(index)),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
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
              if (_submitting && _photos.isNotEmpty)
                LinearProgressIndicator(
                    value: _uploadProgress == 0 ? null : _uploadProgress),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _submitting || _photos.length >= 4 ? null : _pickPhotos,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(_photos.isEmpty
                        ? 'Add photos'
                        : '${_photos.length}/4 photos'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('community-submit-post'),
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: const Text('Post'),
                  ),
                ],
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
