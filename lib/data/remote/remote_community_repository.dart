import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../shared/models/models.dart';
import '../repositories/community_repository.dart';

class RemoteCommunityRepository implements CommunityRepository {
  RemoteCommunityRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<CommunityPage, AppError>> getPosts({int page = 1}) => _api.get(
        '/api/community/posts',
        queryParameters: {'page': page},
        fromJson: (json) {
          final map = json as Map<String, dynamic>;
          return CommunityPage(
            posts: (map['data'] as List)
                .map((item) => Post.fromJson(item as Map<String, dynamic>))
                .toList(),
            currentPage: (map['current_page'] as num).toInt(),
            lastPage: (map['last_page'] as num).toInt(),
          );
        },
      );

  @override
  Future<Result<Post, AppError>> getPostById(String id) => _api.get(
        '/api/community/posts/$id',
        fromJson: (json) => Post.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<Result<Post, AppError>> createPost(
    Post post, {
    List<CommunityPhotoUpload> photos = const [],
    void Function(int, int)? onProgress,
  }) {
    if (photos.isEmpty) {
      return _api.post(
        '/api/community/posts',
        body: {'content': post.content},
        fromJson: (json) => Post.fromJson(json as Map<String, dynamic>),
      );
    }
    final formData = FormData();
    formData.fields.add(MapEntry('content', post.content));
    for (final photo in photos) {
      formData.files.add(
        MapEntry(
          'photos[]',
          MultipartFile.fromBytes(
            photo.bytes,
            filename: photo.filename,
            contentType: DioMediaType.parse(_photoMimeType(photo.filename)),
          ),
        ),
      );
    }

    return _api.postForm(
      '/api/community/posts',
      formData: formData,
      onSendProgress: onProgress,
      fromJson: (json) => Post.fromJson(json as Map<String, dynamic>),
    );
  }

  String _photoMimeType(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    return extension == 'png'
        ? 'image/png'
        : extension == 'webp'
            ? 'image/webp'
            : 'image/jpeg';
  }

  @override
  Future<Result<Post, AppError>> toggleLike(String postId) async {
    final current = await getPostById(postId);
    if (current case Failure(error: final error)) return Failure(error);
    final post = (current as Success<Post, AppError>).value;
    Post parse(dynamic json) => Post.fromJson(json as Map<String, dynamic>);
    return post.isLikedByCurrentUser
        ? _api.deleteData('/api/community/posts/$postId/like', fromJson: parse)
        : _api.put('/api/community/posts/$postId/like', fromJson: parse);
  }

  @override
  Future<Result<Post, AppError>> addComment(
      String postId, Comment comment) async {
    final added = await _api.post<Comment>(
      '/api/community/posts/$postId/comments',
      body: {'content': comment.text},
      fromJson: (json) => Comment.fromJson(json as Map<String, dynamic>),
    );
    if (added case Failure(error: final error)) return Failure(error);
    return getPostById(postId);
  }

  @override
  Future<Result<void, AppError>> deletePost(String postId) =>
      _api.delete('/api/community/posts/$postId');

  @override
  Future<Result<void, AppError>> deleteComment(
          String postId, String commentId) =>
      _api.delete('/api/community/posts/$postId/comments/$commentId');
}
