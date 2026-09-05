<?php

namespace App\Http\Controllers;

use App\Models\Comment;
use App\Models\Post;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CommunityController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $posts = Post::query()
            ->with('user:id,first_name,last_name')
            ->withCount(['likes', 'comments'])
            ->withExists(['likes as is_liked_by_current_user' => fn ($query) => $query->where('user_id', $request->user()->id)])
            ->latest('created_at')->latest('id')->paginate(15);
        $posts->setCollection(
            $posts->getCollection()->map(fn (Post $post) => $this->postData($post, $request))
        );

        return response()->json(['success' => true, 'data' => $posts]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate(['content' => ['required', 'string', 'max:2000']]);
        $post = $request->user()->posts()->create(['content' => trim($validated['content'])]);

        return response()->json(['success' => true, 'data' => $this->loadPost($post, $request)], 201);
    }

    public function show(Request $request, Post $post): JsonResponse
    {
        return response()->json(['success' => true, 'data' => $this->loadPost($post, $request, true)]);
    }

    public function destroy(Request $request, Post $post): JsonResponse
    {
        abort_unless($post->user_id === $request->user()->id, 403);
        $post->comments()->delete();
        $post->delete();
        return response()->json(['success' => true]);
    }

    public function like(Request $request, Post $post): JsonResponse
    {
        $post->likes()->firstOrCreate(['user_id' => $request->user()->id]);
        return response()->json(['success' => true, 'data' => $this->loadPost($post, $request)]);
    }

    public function unlike(Request $request, Post $post): JsonResponse
    {
        $post->likes()->where('user_id', $request->user()->id)->delete();
        return response()->json(['success' => true, 'data' => $this->loadPost($post, $request)]);
    }

    public function comments(Request $request, Post $post): JsonResponse
    {
        $comments = $post->comments()->with('user:id,first_name,last_name')
            ->oldest('created_at')->oldest('id')->paginate(50);
        $comments->setCollection(
            $comments->getCollection()->map(fn (Comment $comment) => $this->commentData($comment, $request))
        );
        return response()->json(['success' => true, 'data' => $comments]);
    }

    public function comment(Request $request, Post $post): JsonResponse
    {
        $validated = $request->validate(['content' => ['required', 'string', 'max:500']]);
        $comment = $post->comments()->create([
            'user_id' => $request->user()->id,
            'content' => trim($validated['content']),
        ]);
        $comment->load('user:id,first_name,last_name');
        return response()->json(['success' => true, 'data' => $this->commentData($comment, $request)], 201);
    }

    public function destroyComment(Request $request, Post $post, Comment $comment): JsonResponse
    {
        abort_unless($comment->post_id === $post->id, 404);
        abort_unless($comment->user_id === $request->user()->id, 403);
        $comment->delete();
        return response()->json(['success' => true]);
    }

    private function loadPost(Post $post, Request $request, bool $comments = false): array
    {
        $post->load('user:id,first_name,last_name')->loadCount(['likes', 'comments']);
        $post->setAttribute('is_liked_by_current_user', $post->likes()->where('user_id', $request->user()->id)->exists());
        if ($comments) {
            $post->load(['comments' => fn ($query) => $query->with('user:id,first_name,last_name')->oldest('created_at')->oldest('id')]);
        }
        return $this->postData($post, $request, $comments);
    }

    private function postData(Post $post, Request $request, bool $includeComments = false): array
    {
        return [
            'id' => (string) $post->id,
            'author_id' => (string) $post->user_id,
            'author_name' => $post->user->full_name,
            'content' => $post->content,
            'created_at' => $post->created_at->toISOString(),
            'like_count' => (int) $post->likes_count,
            'comment_count' => (int) $post->comments_count,
            'is_liked_by_current_user' => (bool) $post->is_liked_by_current_user,
            'is_owned_by_current_user' => $post->user_id === $request->user()->id,
            'comments' => $includeComments ? $post->comments->map(fn ($comment) => $this->commentData($comment, $request))->values() : [],
        ];
    }

    private function commentData(Comment $comment, Request $request): array
    {
        return [
            'id' => (string) $comment->id,
            'post_id' => (string) $comment->post_id,
            'author_id' => (string) $comment->user_id,
            'author_name' => $comment->user->full_name,
            'content' => $comment->content,
            'created_at' => $comment->created_at->toISOString(),
            'is_owned_by_current_user' => $comment->user_id === $request->user()->id,
        ];
    }
}
