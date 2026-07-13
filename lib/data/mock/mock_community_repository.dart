import 'package:synchrofit/data/repositories/community_repository.dart';
import 'package:synchrofit/shared/models/models.dart';

import 'mock_data.dart';

/// Mock implementation of [CommunityRepository] using in-memory data with artificial delays.
class MockCommunityRepository implements CommunityRepository {
  final List<Post> _posts = List.of(MockData.posts);

  @override
  Future<Result<List<Post>, AppError>> getPosts() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Success(List.unmodifiable(_posts));
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
  Future<Result<Post, AppError>> createPost(Post post) async {
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
}
