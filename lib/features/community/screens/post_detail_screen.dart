import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/community_provider.dart';

/// Displays the full detail of a community post including:
/// - Full content, author name, and timestamp
/// - Like button with filled/outlined icon toggle
/// - Comments list (newest first)
/// - Comment input field (max 500 chars) with submit button
///
/// Validates: Requirements 10.3, 10.4, 10.5, 10.6
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({super.key, required this.postId});

  /// The ID of the post to display.
  final String postId;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _commentError;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text;

    // Validate non-empty / non-whitespace
    if (text.trim().isEmpty) {
      setState(() {
        _commentError = 'Comment text is required';
      });
      return;
    }

    setState(() {
      _commentError = null;
    });

    final notifier = ref.read(communityProvider.notifier);
    final error = await notifier.addComment(widget.postId, text);

    if (error == null) {
      _commentController.clear();
    } else {
      if (mounted) {
        setState(() {
          _commentError = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = ref.watch(postDetailProvider(widget.postId));
    final theme = Theme.of(context);

    if (post == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Post')),
        body: const LoadingIndicator(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
      ),
      body: Column(
        children: [
          // Scrollable content area
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Author name
                Text(
                  post.authorName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // Timestamp
                Text(
                  formatRelativeTimestamp(post.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Full content
                Text(
                  post.content,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.md),

                // Like button and count
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        ref
                            .read(communityProvider.notifier)
                            .toggleLike(widget.postId);
                      },
                      icon: Icon(
                        post.isLikedByCurrentUser
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: post.isLikedByCurrentUser
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${post.likeCount}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),

                const Divider(),
                const SizedBox(height: AppSpacing.sm),

                // Comments header
                Text(
                  'Comments (${post.comments.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Comments list
                if (post.comments.isEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(
                      'No comments yet. Be the first to comment!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  ...post.comments.map(
                    (comment) => Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    comment.authorName,
                                    style: theme.textTheme.labelLarge
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    formatRelativeTimestamp(
                                        comment.timestamp),
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: theme
                                          .colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                comment.text,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Comment input area at the bottom
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: SafeArea(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            maxLength: 500,
                            maxLines: 3,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: 'Write a comment...',
                              errorText: _commentError,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.sm,
                              ),
                            ),
                            onChanged: (_) {
                              // Clear error when user starts typing
                              if (_commentError != null) {
                                setState(() {
                                  _commentError = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          onPressed: _submitComment,
                          icon: const Icon(Icons.send),
                          tooltip: 'Submit comment',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
