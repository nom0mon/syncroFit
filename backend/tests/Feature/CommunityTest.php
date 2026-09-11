<?php

namespace Tests\Feature;

use App\Models\Comment;
use App\Models\Post;
use App\Models\PostLike;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class CommunityTest extends TestCase
{
    use RefreshDatabase;

    public function test_feed_is_latest_first_paginated_and_scoped_to_authenticated_users(): void
    {
        $user = User::factory()->create();
        Post::query()->create(['user_id' => $user->id, 'content' => 'Older']);
        $latest = Post::query()->create(['user_id' => $user->id, 'content' => 'Latest']);

        $this->getJson('/api/community/posts')->assertUnauthorized();
        $response = $this->actingAs($user)->getJson('/api/community/posts');
        $response->assertOk()
            ->assertJsonPath('data.per_page', 15)
            ->assertJsonPath('data.data.0.id', (string) $latest->id)
            ->assertJsonPath('data.data.0.author_name', $user->username)
            ->assertJsonPath('data.data.0.comment_count', 0);
    }

    public function test_user_can_create_show_and_soft_delete_their_post(): void
    {
        $user = User::factory()->create();
        $created = $this->actingAs($user)->postJson('/api/community/posts', ['content' => '  My update  ']);
        $created->assertCreated()->assertJsonPath('data.content', 'My update');
        $id = $created->json('data.id');

        PostLike::query()->create(['post_id' => $id, 'user_id' => $user->id]);

        $this->getJson("/api/community/posts/{$id}")->assertOk();
        $this->deleteJson("/api/community/posts/{$id}")->assertOk();
        $this->assertSoftDeleted('posts', ['id' => $id]);
        $this->assertDatabaseMissing('post_likes', ['post_id' => $id]);
        $this->getJson("/api/community/posts/{$id}")->assertNotFound();
    }

    public function test_user_cannot_delete_another_users_post_or_comment(): void
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $post = Post::query()->create(['user_id' => $owner->id, 'content' => 'Owned']);
        $comment = Comment::query()->create(['post_id' => $post->id, 'user_id' => $owner->id, 'content' => 'Mine']);

        $this->actingAs($other)->deleteJson("/api/community/posts/{$post->id}")->assertForbidden();
        $this->deleteJson("/api/community/posts/{$post->id}/comments/{$comment->id}")->assertForbidden();
        $this->assertDatabaseHas('posts', ['id' => $post->id, 'deleted_at' => null]);
        $this->assertDatabaseHas('comments', ['id' => $comment->id, 'deleted_at' => null]);
    }

    public function test_like_and_unlike_are_idempotent(): void
    {
        $user = User::factory()->create();
        $post = Post::query()->create(['user_id' => $user->id, 'content' => 'Like me']);
        $url = "/api/community/posts/{$post->id}/like";

        $this->actingAs($user)->putJson($url)->assertOk()->assertJsonPath('data.like_count', 1);
        $this->putJson($url)->assertOk()->assertJsonPath('data.like_count', 1);
        $this->assertSame(1, PostLike::query()->count());
        $this->deleteJson($url)->assertOk()->assertJsonPath('data.like_count', 0);
        $this->deleteJson($url)->assertOk()->assertJsonPath('data.like_count', 0);
    }

    public function test_comments_are_validated_and_returned_oldest_first(): void
    {
        $user = User::factory()->create();
        $post = Post::query()->create(['user_id' => $user->id, 'content' => 'Discuss']);
        $url = "/api/community/posts/{$post->id}/comments";

        $this->actingAs($user)->postJson($url, ['content' => ''])->assertUnprocessable();
        $firstResponse = $this->postJson($url, ['content' => 'First'])->assertCreated();
        $firstResponse->assertJsonPath('data.author_name', $user->username);
        $first = $firstResponse->json('data.id');
        $second = $this->postJson($url, ['content' => 'Second'])->assertCreated()->json('data.id');

        $this->getJson($url)->assertOk()
            ->assertJsonPath('data.data.0.id', $first)
            ->assertJsonPath('data.data.1.id', $second);
        $this->deleteJson("{$url}/{$first}")->assertOk();
        $this->assertSoftDeleted('comments', ['id' => $first]);
    }

    public function test_post_and_comment_character_limits_are_enforced(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user)->postJson('/api/community/posts', ['content' => str_repeat('a', 2001)])
            ->assertUnprocessable();
        $post = Post::query()->create(['user_id' => $user->id, 'content' => 'Post']);
        $this->postJson("/api/community/posts/{$post->id}/comments", ['content' => str_repeat('a', 501)])
            ->assertUnprocessable();
    }

    public function test_user_can_create_photo_post_and_media_requires_authentication(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        $response = $this->actingAs($user)->post('/api/community/posts', [
            'content' => 'Photo update',
            'photos' => [
                $this->png('one.png'),
                $this->png('two.png'),
            ],
        ], ['Accept' => 'application/json']);

        $response->assertCreated()->assertJsonCount(2, 'data.media');
        $postId = $response->json('data.id');
        $mediaId = $response->json('data.media.0.id');
        $path = \App\Models\PostMedia::query()->firstOrFail()->path;
        Storage::disk('local')->assertExists($path);

        $this->app['auth']->forgetGuards();
        $this->getJson("/api/community/posts/{$postId}/media/{$mediaId}")->assertUnauthorized();
        $this->actingAs($user)->get("/api/community/posts/{$postId}/media/{$mediaId}")->assertOk();
    }

    public function test_photo_validation_and_storage_cleanup_are_enforced(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        $photos = collect(range(1, 5))->map(fn ($number) =>
            $this->png("{$number}.png"))->all();
        $this->actingAs($user)->post('/api/community/posts', ['photos' => $photos], ['Accept' => 'application/json'])
            ->assertUnprocessable()->assertJsonValidationErrors('photos');

        $created = $this->post('/api/community/posts', [
            'photos' => [$this->png('valid.png')],
        ], ['Accept' => 'application/json'])->assertCreated();
        $postId = $created->json('data.id');
        $path = \App\Models\PostMedia::query()->firstOrFail()->path;
        $this->deleteJson("/api/community/posts/{$postId}")->assertOk();
        Storage::disk('local')->assertMissing($path);
        $this->assertDatabaseMissing('post_media', ['post_id' => $postId]);
    }

    private function png(string $name): UploadedFile
    {
        return UploadedFile::fake()->createWithContent(
            $name,
            base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
        );
    }
}
