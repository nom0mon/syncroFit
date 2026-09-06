import 'package:synchrofit/data/repositories/community_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

import 'mock_data.dart';

/// Mock implementation of [CommunityRepository] using in-memory data with artificial delays.
class MockCommunityRepository implements CommunityRepository {
  final List<Post> _posts = List.of(MockData.posts);

  @override
  Future<Result<CommunityPage, AppError>> getPosts({int page = 1}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Success(CommunityPage(posts: List.unmodifiable(_posts), currentPage: 1, lastPage: 1));
  }

  @override
  Future<Result<Post, AppError>> getPostById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _posts.indexWhere((p) => p.id == id);
    if (index == -1) {
      return Failure(NotFoundError(entityType: 'Post', id: id));
    }
    return Success(_posts[index]);
  }

  @override
  Future<Result<Post, AppError>> createPost(Post post, {List<CommunityPhotoUpload> photos = const [], void Function(int, int)? onProgress}) async {
    await Future.delayed(const Duration(milliseconds: 350));

    _posts.insert(0, post);
    return Success(post);
  }

  @override
  Future<Result<Post, AppError>> toggleLike(String postId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) {
      return Failure(NotFoundError(entityType: 'Post', id: postId));
    }

    final post = _posts[index];
    final updatedPost = Post(
      id: post.id,
      authorName: post.authorName,
      content: post.content,
      timestamp: post.timestamp,
      likeCount:
          post.isLikedByCurrentUser
              ? post.likeCount - 1
              : post.likeCount + 1,
      isLikedByCurrentUser: !post.isLikedByCurrentUser,
      comments: post.comments,
    );

    _posts[index] = updatedPost;
    return Success(updatedPost);
  }

  @override
  Future<Result<Post, AppError>> addComment(
    String postId,
    Comment comment,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Validate non-whitespace text
    if (comment.text.trim().isEmpty) {
      return Failure(
        ValidationError(
          fieldErrors: {'text': 'Comment text cannot be empty'},
        ),
      );
    }

    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) {
      return Failure(NotFoundError(entityType: 'Post', id: postId));
    }

    final post = _posts[index];
    final updatedComments = [comment, ...post.comments];
    final updatedPost = Post(
      id: post.id,
      authorName: post.authorName,
      content: post.content,
      timestamp: post.timestamp,
      likeCount: post.likeCount,
      isLikedByCurrentUser: post.isLikedByCurrentUser,
      comments: updatedComments,
    );

    _posts[index] = updatedPost;
    return Success(updatedPost);
  }

  @override
  Future<Result<void, AppError>> deletePost(String postId) async {
    _posts.removeWhere((post) => post.id == postId);
    return const Success(null);
  }

  @override
  Future<Result<void, AppError>> deleteComment(String postId, String commentId) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) return Failure(NotFoundError(entityType: 'Post', id: postId));
    final post = _posts[index];
    final comments = post.comments.where((item) => item.id != commentId).toList();
    _posts[index] = post.copyWith(comments: comments, commentCount: comments.length);
    return const Success(null);
  }
}
