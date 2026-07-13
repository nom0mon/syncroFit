import 'package:synchrofit/shared/models/models.dart';

/// Abstract interface for community feed operations.
abstract class CommunityRepository {
  /// Retrieves all community posts.
  Future<Result<List<Post>, AppError>> getPosts();

  /// Retrieves a single post by its ID.
  Future<Result<Post, AppError>> getPostById(String id);

  /// Creates a new community post.
  Future<Result<Post, AppError>> createPost(Post post);

  /// Toggles the like state for a post.
  Future<Result<Post, AppError>> toggleLike(String postId);

  /// Adds a comment to a post.
  Future<Result<Post, AppError>> addComment(String postId, Comment comment);
}
