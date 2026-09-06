import 'package:synchrofit/shared/models/models.dart';
import 'dart:typed_data';

class CommunityPhotoUpload {
  const CommunityPhotoUpload({required this.bytes, required this.filename});
  final Uint8List bytes;
  final String filename;
}

/// Abstract interface for community feed operations.
abstract class CommunityRepository {
  /// Retrieves all community posts.
  Future<Result<CommunityPage, AppError>> getPosts({int page = 1});

  /// Retrieves a single post by its ID.
  Future<Result<Post, AppError>> getPostById(String id);

  /// Creates a new community post.
  Future<Result<Post, AppError>> createPost(Post post, {List<CommunityPhotoUpload> photos = const [], void Function(int, int)? onProgress});

  /// Toggles the like state for a post.
  Future<Result<Post, AppError>> toggleLike(String postId);

  /// Adds a comment to a post.
  Future<Result<Post, AppError>> addComment(String postId, Comment comment);

  Future<Result<void, AppError>> deletePost(String postId);
  Future<Result<void, AppError>> deleteComment(String postId, String commentId);
}

class CommunityPage {
  const CommunityPage({required this.posts, required this.currentPage, required this.lastPage});
  final List<Post> posts;
  final int currentPage;
  final int lastPage;
  bool get hasMore => currentPage < lastPage;
}
