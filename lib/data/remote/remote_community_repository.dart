import '../../core/network/api_client.dart';
import '../../shared/models/models.dart';
import '../repositories/community_repository.dart';

class RemoteCommunityRepository implements CommunityRepository {
  RemoteCommunityRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<List<Post>, AppError>> getPosts() => _api.get(
        '/api/community/posts',
        fromJson: (json) => ((json as Map<String, dynamic>)['data'] as List)
            .map((item) => Post.fromJson(item as Map<String, dynamic>)).toList(),
      );

  @override
  Future<Result<Post, AppError>> getPostById(String id) => _api.get(
        '/api/community/posts/$id',
        fromJson: (json) => Post.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<Result<Post, AppError>> createPost(Post post) => _api.post(
        '/api/community/posts', body: {'content': post.content},
        fromJson: (json) => Post.fromJson(json as Map<String, dynamic>),
      );

  @override
  Future<Result<Post, AppError>> toggleLike(String postId) async {
    final current = await getPostById(postId);
    if (current case Failure(error: final error)) return Failure(error);
    final post = (current as Success<Post, AppError>).value;
    final parse = (dynamic json) => Post.fromJson(json as Map<String, dynamic>);
    return post.isLikedByCurrentUser
        ? _api.deleteData('/api/community/posts/$postId/like', fromJson: parse)
        : _api.put('/api/community/posts/$postId/like', fromJson: parse);
  }

  @override
  Future<Result<Post, AppError>> addComment(String postId, Comment comment) async {
    final added = await _api.post<Comment>(
      '/api/community/posts/$postId/comments', body: {'content': comment.text},
      fromJson: (json) => Comment.fromJson(json as Map<String, dynamic>),
    );
    if (added case Failure(error: final error)) return Failure(error);
    return getPostById(postId);
  }

  @override
  Future<Result<void, AppError>> deletePost(String postId) =>
      _api.delete('/api/community/posts/$postId');

  @override
  Future<Result<void, AppError>> deleteComment(String postId, String commentId) =>
      _api.delete('/api/community/posts/$postId/comments/$commentId');
}
