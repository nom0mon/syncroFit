<?php

namespace Tests\Feature;

use App\Models\Comment;
use App\Models\Post;
use App\Models\PostLike;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
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
            ->assertJsonPath('data.data.0.comment_count', 0);
    }

    public function test_user_can_create_show_and_soft_delete_their_post(): void
    {
        $user = User::factory()->create();
        $created = $this->actingAs($user)->postJson('/api/community/posts', ['content' => '  My update  ']);
        $created->assertCreated()->assertJsonPath('data.content', 'My update');
        $id = $created->json('data.id');

        $this->getJson("/api/community/posts/{$id}")->assertOk();
        $this->deleteJson("/api/community/posts/{$id}")->assertOk();
        $this->assertSoftDeleted('posts', ['id' => $id]);
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
        $first = $this->postJson($url, ['content' => 'First'])->assertCreated()->json('data.id');
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
}
