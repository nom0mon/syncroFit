import 'package:flutter_test/flutter_test.dart';
import 'package:synchrofit/shared/models/models.dart';

void main() {
  test('post parses the Community API contract and round trips cache data', () {
    final post = Post.fromJson({
      'id': '12',
      'author_id': '3',
      'author_name': 'Taylor Smith',
      'content': 'A useful update',
      'created_at': '2026-09-06T10:00:00.000Z',
      'like_count': 4,
      'comment_count': 1,
      'is_liked_by_current_user': true,
      'is_owned_by_current_user': false,
      'media': [
        {
          'id': '21', 'url': 'http://localhost/media/21',
          'mime_type': 'image/png', 'position': 0, 'width': 800, 'height': 600,
        }
      ],
      'comments': [
        {
          'id': '8', 'post_id': '12', 'author_id': '3',
          'author_name': 'Taylor Smith', 'content': 'First',
          'created_at': '2026-09-06T10:01:00.000Z',
          'is_owned_by_current_user': false,
        }
      ],
    });

    expect(post.commentCount, 1);
    expect(post.isLikedByCurrentUser, isTrue);
    expect(post.comments.single.text, 'First');
    expect(post.media.single.width, 800);
    expect(Post.fromJson(post.toJson()).toJson(), post.toJson());
  });
}
