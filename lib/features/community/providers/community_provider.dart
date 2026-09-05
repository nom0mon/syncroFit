import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/remote/providers.dart';
import '../../../data/repositories/community_repository.dart';
import '../../../shared/models/models.dart';

/// Provides the [CommunityRepository] instance used by the community module.
final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return ref.watch(remoteCommunityRepositoryProvider);
});

/// The state exposed by the community provider.
class CommunityState {
  /// The list of all community posts.
  final List<Post> posts;

  /// Error message if something went wrong, null otherwise.
  final String? errorMessage;

  const CommunityState({
    this.posts = const [],
    this.errorMessage,
  });

  /// Returns a copy of this state with optional overrides.
  CommunityState copyWith({
    List<Post>? posts,
    String? errorMessage,
  }) {
    return CommunityState(
      posts: posts ?? this.posts,
      errorMessage: errorMessage,
    );
  }
}

/// Provides the community data as an async value, managed by [CommunityNotifier].
final communityProvider =
    AsyncNotifierProvider<CommunityNotifier, CommunityState>(() {
  return CommunityNotifier();
});

/// An [AsyncNotifier] that manages community posts, likes, and comments.
class CommunityNotifier extends AsyncNotifier<CommunityState> {
  CommunityRepository get _repo => ref.read(communityRepositoryProvider);
  final Set<String> _pendingLikes = {};

  @override
  Future<CommunityState> build() async {
    final result = await _repo.getPosts();
    return switch (result) {
      Success(value: final posts) => CommunityState(posts: posts),
      Failure(error: final error) =>
        CommunityState(errorMessage: error.message),
    };
  }

  /// Toggles the like state for a post.
  ///
  /// If the post is currently liked, it decrements the like count and sets
  /// the liked state to false. If unliked, it increments the count and sets
  /// liked to true.
  ///
  /// Validates: Requirements 10.4
  Future<void> toggleLike(String postId) async {
    if (!_pendingLikes.add(postId)) return;
    final currentState = state.valueOrNull;
    if (currentState == null) {
      _pendingLikes.remove(postId);
      return;
    }

    // Optimistically update the UI state
    final posts = currentState.posts.map((post) {
      if (post.id == postId) {
        return post.copyWith(
          likeCount: post.isLikedByCurrentUser
              ? (post.likeCount - 1).clamp(0, post.likeCount)
              : post.likeCount + 1,
          isLikedByCurrentUser: !post.isLikedByCurrentUser,
        );
      }
      return post;
    }).toList();

    state = AsyncValue.data(currentState.copyWith(posts: posts));

    // Also update the repository in background
    final result = await _repo.toggleLike(postId);
    _pendingLikes.remove(postId);
    switch (result) {
      case Success(value: final updated):
        _replacePost(updated);
      case Failure():
        state = AsyncValue.data(currentState);
    }
  }

  /// Adds a comment to a post.
  ///
  /// Validates that the text contains at least one non-whitespace character.
  /// On success, prepends the new comment to the post's comment list.
  ///
  /// Returns null on success, or a validation error message on failure.
  ///
  /// Validates: Requirements 10.5, 10.6
  Future<String?> addComment(String postId, String text) async {
    // Validate non-whitespace content
    if (text.trim().isEmpty) {
      return 'Comment text is required';
    }

    final currentState = state.valueOrNull;
    if (currentState == null) return 'State not loaded';

    final comment = Comment(
      id: 'comment_${DateTime.now().millisecondsSinceEpoch}',
      postId: postId,
      authorName: 'You',
      text: text,
      timestamp: DateTime.now(),
    );

    // Optimistically update the UI state — prepend comment to the post
    final posts = currentState.posts.map((post) {
      if (post.id == postId) {
        return post.copyWith(
          comments: [...post.comments, comment],
          commentCount: post.commentCount + 1,
        );
      }
      return post;
    }).toList();

    state = AsyncValue.data(currentState.copyWith(posts: posts));

    // Also persist to the repository in background
    final result = await _repo.addComment(postId, comment);
    return switch (result) {
      Success(value: final updated) => (_replacePost(updated), null).$2,
      Failure(error: final error) => (state = AsyncValue.data(currentState), error.message).$2,
    };
  }

  Future<String?> createPost(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return 'Post text is required';
    if (trimmed.length > 2000) return 'Posts can contain up to 2,000 characters.';
    final result = await _repo.createPost(Post(
      id: '', authorName: '', content: trimmed, timestamp: DateTime.now(),
      likeCount: 0, isLikedByCurrentUser: false, comments: const [],
    ));
    return switch (result) {
      Success(value: final post) => (_prependPost(post), null).$2,
      Failure(error: final error) => error.message,
    };
  }

  Future<String?> deletePost(String postId) async {
    final previous = state.valueOrNull;
    if (previous == null) return 'State not loaded';
    state = AsyncValue.data(previous.copyWith(
      posts: previous.posts.where((post) => post.id != postId).toList(),
    ));
    final result = await _repo.deletePost(postId);
    if (result case Failure(error: final error)) {
      state = AsyncValue.data(previous);
      return error.message;
    }
    return null;
  }

  Future<String?> deleteComment(String postId, String commentId) async {
    final previous = state.valueOrNull;
    if (previous == null) return 'State not loaded';
    final posts = previous.posts.map((post) {
      if (post.id != postId) return post;
      final comments = post.comments.where((item) => item.id != commentId).toList();
      return post.copyWith(comments: comments, commentCount: (post.commentCount - 1).clamp(0, post.commentCount));
    }).toList();
    state = AsyncValue.data(previous.copyWith(posts: posts));
    final result = await _repo.deleteComment(postId, commentId);
    if (result case Failure(error: final error)) {
      state = AsyncValue.data(previous);
      return error.message;
    }
    return null;
  }

  Future<String?> loadPost(String postId) async {
    final result = await _repo.getPostById(postId);
    if (result case Success(value: final post)) {
      _replacePost(post);
      return null;
    }
    return (result as Failure<Post, AppError>).error.message;
  }

  void _prependPost(Post post) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncValue.data(current.copyWith(posts: [post, ...current.posts]));
  }

  void _replacePost(Post updated) {
    final current = state.valueOrNull;
    if (current != null) state = AsyncValue.data(current.copyWith(
      posts: current.posts.map((post) => post.id == updated.id ? updated : post).toList(),
    ));
  }

  /// Returns a post by its ID, or null if not found.
  Post? getPostById(String postId) {
    final currentState = state.valueOrNull;
    if (currentState == null) return null;

    try {
      return currentState.posts.firstWhere((p) => p.id == postId);
    } catch (_) {
      return null;
    }
  }

  /// Truncates content to [maxLength] characters, appending "…" if truncated.
  ///
  /// If content.length > maxLength, returns content.substring(0, maxLength) + "…".
  /// Otherwise returns the full content.
  ///
  /// Validates: Requirements 10.1
  static String truncateContent(String content, {int maxLength = 150}) {
    if (content.length > maxLength) {
      return '${content.substring(0, maxLength)}\u2026';
    }
    return content;
  }
}

/// A convenience provider to get a single post by ID.
final postDetailProvider = Provider.family<Post?, String>((ref, postId) {
  final communityState = ref.watch(communityProvider);
  return communityState.whenOrNull(
    data: (state) {
      try {
        return state.posts.firstWhere((p) => p.id == postId);
      } catch (_) {
        return null;
      }
    },
  );
});
