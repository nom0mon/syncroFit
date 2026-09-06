import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_display.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/safe_layout.dart';
import '../providers/community_provider.dart';
import '../widgets/community_photo_gallery.dart';

/// Displays a post, its comments, and a keyboard-safe comment form.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  String? _commentError;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(communityProvider.notifier).loadPost(widget.postId));
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text;
    if (text.trim().isEmpty) {
      setState(() => _commentError = 'Comment text is required');
      return;
    }

    setState(() => _commentError = null);
    final error = await ref
        .read(communityProvider.notifier)
        .addComment(widget.postId, text);

    if (!mounted) return;
    if (error == null) {
      _commentController.clear();
    } else {
      setState(() => _commentError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final communityAsync = ref.watch(communityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (ref.watch(postDetailProvider(widget.postId))?.isOwnedByCurrentUser ?? false)
            IconButton(
              tooltip: 'Delete post',
              onPressed: _confirmDeletePost,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        child: communityAsync.when(
          loading: () => const _PostStatePage(
            child: LoadingIndicator(),
          ),
          error: (error, _) => _PostStatePage(
            child: ErrorDisplay(
              message: error.toString(),
              onRetry: () => ref.invalidate(communityProvider),
            ),
          ),
          data: (state) {
            if (state.errorMessage != null) {
              return _PostStatePage(
                child: ErrorDisplay(
                  message: state.errorMessage!,
                  onRetry: () => ref.invalidate(communityProvider),
                ),
              );
            }

            final post = ref.watch(postDetailProvider(widget.postId));
            if (post == null) {
              return const _PostStatePage(
                child: EmptyState(
                  icon: Icons.forum_outlined,
                  message: 'This post is unavailable.',
                ),
              );
            }

            return _PostDetailBody(
              post: post,
              commentController: _commentController,
              commentError: _commentError,
              onCommentChanged: () {
                if (_commentError != null) {
                  setState(() => _commentError = null);
                }
              },
              onSubmitComment: _submitComment,
              onDeleteComment: _confirmDeleteComment,
              onToggleLike: () => ref
                  .read(communityProvider.notifier)
                  .toggleLike(widget.postId),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDeletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This removes the post and its comments.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await ref.read(communityProvider.notifier).deletePost(widget.postId);
    if (!mounted) return;
    if (error == null) {
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _confirmDeleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      final error = await ref.read(communityProvider.notifier).deleteComment(widget.postId, comment.id);
      if (mounted && error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }
}

class _PostStatePage extends StatelessWidget {
  const _PostStatePage({required this.child});

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

class _PostDetailBody extends StatelessWidget {
  const _PostDetailBody({
    required this.post,
    required this.commentController,
    required this.commentError,
    required this.onCommentChanged,
    required this.onSubmitComment,
    required this.onToggleLike,
    required this.onDeleteComment,
  });

  final Post post;
  final TextEditingController commentController;
  final String? commentError;
  final VoidCallback onCommentChanged;
  final VoidCallback onSubmitComment;
  final VoidCallback onToggleLike;
  final ValueChanged<Comment> onDeleteComment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ResponsiveConstrainedPage(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              children: [
                Text(
                  post.authorName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formatRelativeTimestamp(post.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  post.content,
                  style: theme.textTheme.bodyLarge,
                  softWrap: true,
                ),
                if (post.media.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  CommunityPhotoGallery(photos: post.media),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    IconButton(
                      onPressed: onToggleLike,
                      tooltip: post.isLikedByCurrentUser
                          ? 'Unlike post'
                          : 'Like post',
                      icon: Icon(
                        post.isLikedByCurrentUser
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: post.isLikedByCurrentUser
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        '${post.likeCount}',
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Comments (${post.comments.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (post.comments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md,
                    ),
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final comment in post.comments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _CommentCard(
                        comment: comment,
                        onDelete: comment.isOwnedByCurrentUser ? () => onDeleteComment(comment) : null,
                      ),
                    ),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: SafeBottomActionBar(
            avoidKeyboard: false,
            verticalPadding: AppSpacing.sm,
            backgroundColor: theme.colorScheme.surface,
            child: _CommentForm(
              controller: commentController,
              errorText: commentError,
              onChanged: onCommentChanged,
              onSubmit: onSubmitComment,
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment, this.onDelete});

  final Comment comment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = ResponsiveStandards.widthClassFor(
                    constraints.maxWidth,
                  ) ==
                  AppWidthClass.compact;
              final name = Text(
                comment.authorName,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              );
              final timestamp = Text(
                formatRelativeTimestamp(comment.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    name,
                    const SizedBox(height: AppSpacing.xs),
                    timestamp,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: name),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(child: timestamp),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            comment.text,
            style: theme.textTheme.bodyMedium,
            softWrap: true,
          ),
          if (onDelete != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete'),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommentForm extends StatelessWidget {
  const _CommentForm({
    required this.controller,
    required this.errorText,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final widthClass = ResponsiveStandards.widthClassFor(
          constraints.maxWidth,
        );
        final stackAction =
            widthClass == AppWidthClass.compact || textScale >= 1.5;
        final field = TextField(
          key: const Key('community-comment-field'),
          controller: controller,
          maxLength: 500,
          maxLines: 3,
          minLines: 1,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            hintText: 'Write a comment...',
            errorText: errorText,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
          ),
          onChanged: (_) => onChanged(),
        );

        if (stackAction) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field,
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('community-submit-comment'),
                  onPressed: onSubmit,
                  icon: const Icon(Icons.send),
                  label: const Text('Send'),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: field),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              key: const Key('community-submit-comment'),
              onPressed: onSubmit,
              icon: const Icon(Icons.send),
              tooltip: 'Submit comment',
            ),
          ],
        );
      },
    );
  }
}
