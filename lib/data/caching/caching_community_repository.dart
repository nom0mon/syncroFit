import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/connectivity_monitor.dart';
import '../../shared/models/models.dart';
import '../repositories/community_repository.dart';

class CachingCommunityRepository implements CommunityRepository {
  CachingCommunityRepository({required CommunityRepository remote, required ConnectivityMonitor connectivity, required String userId})
      : _remote = remote, _connectivity = connectivity, _cacheKey = 'community_feed_$userId';

  final CommunityRepository _remote;
  final ConnectivityMonitor _connectivity;
  final String _cacheKey;

  @override
  Future<Result<CommunityPage, AppError>> getPosts({int page = 1}) async {
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      final result = await _remote.getPosts(page: page);
      if (page == 1 && result is Success<CommunityPage, AppError>) {
        await _write(result.value.posts);
      }
      return result;
    }
    if (page > 1) return const Success(CommunityPage(posts: [], currentPage: 1, lastPage: 1));
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_cacheKey);
    if (encoded == null) return const Success(CommunityPage(posts: [], currentPage: 1, lastPage: 1));
    final posts = (jsonDecode(encoded) as List).map((item) => Post.fromJson(item as Map<String, dynamic>)).toList();
    return Success(CommunityPage(posts: posts, currentPage: 1, lastPage: 1));
  }

  Future<Result<T, AppError>> _online<T>(Future<Result<T, AppError>> Function() action) {
    if (_connectivity.currentStatus != ConnectivityStatus.online) return Future.value(Failure(NetworkError()));
    return action();
  }

  @override
  Future<Result<Post, AppError>> getPostById(String id) => _online(() => _remote.getPostById(id));
  @override
  Future<Result<Post, AppError>> createPost(Post post, {List<CommunityPhotoUpload> photos = const [], void Function(int, int)? onProgress}) async {
    final result = await _online(() => _remote.createPost(post, photos: photos, onProgress: onProgress));
    if (result case Success(value: final created)) await _upsert(created, prepend: true);
    return result;
  }
  @override
  Future<Result<Post, AppError>> toggleLike(String postId) async {
    final result = await _online(() => _remote.toggleLike(postId));
    if (result case Success(value: final post)) await _upsert(post);
    return result;
  }
  @override
  Future<Result<Post, AppError>> addComment(String postId, Comment comment) async {
    final result = await _online(() => _remote.addComment(postId, comment));
    if (result case Success(value: final post)) await _upsert(post);
    return result;
  }
  @override
  Future<Result<void, AppError>> deletePost(String postId) async {
    final result = await _online(() => _remote.deletePost(postId));
    if (result is Success<void, AppError>) {
      final posts = await _read();
      await _write(posts.where((post) => post.id != postId).toList());
    }
    return result;
  }
  @override
  Future<Result<void, AppError>> deleteComment(String postId, String commentId) async {
    final result = await _online(() => _remote.deleteComment(postId, commentId));
    if (result is Success<void, AppError>) {
      final posts = await _read();
      await _write(posts.map((post) {
        if (post.id != postId) return post;
        return post.copyWith(
          comments: post.comments.where((comment) => comment.id != commentId).toList(),
          commentCount: (post.commentCount - 1).clamp(0, post.commentCount),
        );
      }).toList());
    }
    return result;
  }

  Future<List<Post>> _read() async {
    final encoded = (await SharedPreferences.getInstance()).getString(_cacheKey);
    if (encoded == null) return [];
    return (jsonDecode(encoded) as List)
        .map((item) => Post.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> _upsert(Post updated, {bool prepend = false}) async {
    final posts = await _read();
    final exists = posts.any((post) => post.id == updated.id);
    final next = exists
        ? posts.map((post) => post.id == updated.id ? updated : post).toList()
        : (prepend ? [updated, ...posts] : [...posts, updated]);
    await _write(next);
  }

  Future<void> _write(List<Post> posts) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_cacheKey, jsonEncode(posts.map((post) => post.toJson()).toList()));
  }
}
