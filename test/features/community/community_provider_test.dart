import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/data/repositories/community_repository.dart';
import 'package:synchrofit/features/community/providers/community_provider.dart';
import 'package:synchrofit/shared/models/models.dart';
import 'dart:typed_data';

void main() {
  Post post({bool liked = false, int likes = 0, String content = 'Update'}) =>
      Post(
        id: '1',
        authorName: 'Alex',
        content: content,
        timestamp: DateTime.utc(2026, 9, 6),
        likeCount: likes,
        isLikedByCurrentUser: liked,
        comments: const [],
      );

  test('failed optimistic like rolls back and duplicate rapid tap is ignored',
      () async {
    final repository = _FakeCommunityRepository(post(), failLike: true);
    final container = ProviderContainer(overrides: [
      communityUserIdProvider.overrideWithValue('test-user'),
      communityRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await container.read(communityProvider.future);

    final first = container.read(communityProvider.notifier).toggleLike('1');
    final second = container.read(communityProvider.notifier).toggleLike('1');
    expect(container.read(communityProvider).value!.posts.single.likeCount, 1);
    await Future.wait([first, second]);

    expect(repository.likeCalls, 1);
    expect(container.read(communityProvider).value!.posts.single.likeCount, 0);
    expect(
        container
            .read(communityProvider)
            .value!
            .posts
            .single
            .isLikedByCurrentUser,
        isFalse);
  });

  test('created posts are inserted at the top', () async {
    final repository = _FakeCommunityRepository(post());
    final container = ProviderContainer(overrides: [
      communityUserIdProvider.overrideWithValue('test-user'),
      communityRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await container.read(communityProvider.future);

    expect(
        await container.read(communityProvider.notifier).createPost('New post'),
        isNull);
    expect(container.read(communityProvider).value!.posts.first.content,
        'New post');
  });

  test('photo uploads are forwarded when a post is created', () async {
    final repository = _FakeCommunityRepository(post());
    final container = ProviderContainer(overrides: [
      communityUserIdProvider.overrideWithValue('test-user'),
      communityRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await container.read(communityProvider.future);
    final photo = CommunityPhotoUpload(
        bytes: Uint8List.fromList([1, 2, 3]), filename: 'photo.jpg');

    expect(
        await container
            .read(communityProvider.notifier)
            .createPost('', photos: [photo]),
        isNull);
    expect(repository.lastPhotoCount, 1);
  });

  test('optimistic comments use the signed-in username', () async {
    final repository = _FakeCommunityRepository(post());
    final container = ProviderContainer(overrides: [
      communityUserIdProvider.overrideWithValue('test-user'),
      communityUsernameProvider.overrideWithValue('member.username'),
      communityRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    await container.read(communityProvider.future);

    await container
        .read(communityProvider.notifier)
        .addComment('1', 'Testing usernames');

    expect(repository.lastComment?.authorName, 'member.username');
  });

  test('switching accounts rebuilds the feed for the new user', () async {
    final activeUser = StateProvider<String?>((ref) => 'user-a');
    final repositories = {
      'user-a': _FakeCommunityRepository(post(content: 'Account A')),
      'user-b': _FakeCommunityRepository(post(content: 'Account B')),
    };
    final container = ProviderContainer(overrides: [
      communityUserIdProvider.overrideWith(
        (ref) => ref.watch(activeUser),
      ),
      communityRepositoryProvider.overrideWith(
        (ref) => repositories[ref.watch(activeUser)]!,
      ),
    ]);
    addTearDown(container.dispose);

    expect(
      (await container.read(communityProvider.future)).posts.single.content,
      'Account A',
    );

    container.read(activeUser.notifier).state = 'user-b';

    expect(
      (await container.read(communityProvider.future)).posts.single.content,
      'Account B',
    );
  });
}

class _FakeCommunityRepository implements CommunityRepository {
  _FakeCommunityRepository(this.initial, {this.failLike = false});
  final Post initial;
  final bool failLike;
  int likeCalls = 0;
  int lastPhotoCount = 0;
  Comment? lastComment;

  @override
  Future<Result<CommunityPage, AppError>> getPosts({int page = 1}) async =>
      Success(CommunityPage(posts: [initial], currentPage: 1, lastPage: 1));
  @override
  Future<Result<Post, AppError>> getPostById(String id) async =>
      Success(initial);
  @override
  Future<Result<Post, AppError>> createPost(Post post,
      {List<CommunityPhotoUpload> photos = const [],
      void Function(int, int)? onProgress}) async {
    lastPhotoCount = photos.length;
    return Success(Post(
      id: '2',
      authorName: 'You',
      content: post.content,
      timestamp: DateTime.now(),
      likeCount: 0,
      isLikedByCurrentUser: false,
      comments: const [],
      isOwnedByCurrentUser: true,
    ));
  }

  @override
  Future<Result<Post, AppError>> toggleLike(String postId) async {
    likeCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return failLike
        ? Failure(ServerError(statusCode: 500, serverMessage: 'Failed'))
        : Success(initial.copyWith(likeCount: 1, isLikedByCurrentUser: true));
  }

  @override
  Future<Result<Post, AppError>> addComment(
      String postId, Comment comment) async {
    lastComment = comment;
    return Success(initial);
  }
  @override
  Future<Result<void, AppError>> deletePost(String postId) async =>
      const Success(null);
  @override
  Future<Result<void, AppError>> deleteComment(
          String postId, String commentId) async =>
      const Success(null);
}
