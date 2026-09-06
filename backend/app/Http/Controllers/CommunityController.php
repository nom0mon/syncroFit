<?php

namespace App\Http\Controllers;

use App\Models\Comment;
use App\Models\Post;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use App\Services\CommunityMediaStorage;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\ValidationException;

class CommunityController extends Controller
{
    public function __construct(private readonly CommunityMediaStorage $mediaStorage) {}

    public function index(Request $request): JsonResponse
    {
        $posts = Post::query()
            ->with(['user:id,first_name,last_name', 'media'])
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
        $validated = $request->validate([
            'content' => ['nullable', 'string', 'max:2000'],
            'photos' => ['nullable', 'array', 'max:4'],
            'photos.*' => ['file', 'image', 'mimes:jpg,jpeg,png,webp', 'max:8192', 'dimensions:max_width=4096,max_height=4096'],
        ]);
        if (trim((string) ($validated['content'] ?? '')) === '' && ! $request->hasFile('photos')) {
            throw ValidationException::withMessages(['content' => 'Write something or add at least one photo.']);
        }

        $stored = [];
        try {
            $post = DB::transaction(function () use ($request, $validated, &$stored) {
                $post = $request->user()->posts()->create(['content' => trim((string) ($validated['content'] ?? ''))]);
                foreach ($request->file('photos', []) as $position => $photo) {
                    $metadata = $this->mediaStorage->store($photo, $request->user()->id);
                    $stored[] = $metadata;
                    $post->media()->create([...$metadata, 'position' => $position]);
                }
                return $post;
            });
        } catch (\Throwable $error) {
            foreach ($stored as $item) $this->mediaStorage->delete($item['disk'], $item['path']);
            throw $error;
        }

        return response()->json(['success' => true, 'data' => $this->loadPost($post, $request)], 201);
    }

    public function show(Request $request, Post $post): JsonResponse
    {
        return response()->json(['success' => true, 'data' => $this->loadPost($post, $request, true)]);
    }

    public function destroy(Request $request, Post $post): JsonResponse
    {
        abort_unless($post->user_id === $request->user()->id, 403);
        foreach ($post->media as $media) $this->mediaStorage->delete($media->disk, $media->path);
        $post->media()->delete();
        $post->comments()->delete();
        $post->likes()->delete();
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

    public function media(Post $post, \App\Models\PostMedia $media)
    {
        abort_unless($media->post_id === $post->id, 404);
        abort_unless(Storage::disk($media->disk)->exists($media->path), 404);
        if ($media->disk !== 'local') {
            return redirect()->away(Storage::disk($media->disk)->temporaryUrl($media->path, now()->addMinutes(10)));
        }
        return Storage::disk($media->disk)->response($media->path, null, [
            'Content-Type' => $media->mime_type,
            'Cache-Control' => 'private, max-age=3600',
        ]);
    }

    private function loadPost(Post $post, Request $request, bool $comments = false): array
    {
        $post->load(['user:id,first_name,last_name', 'media'])->loadCount(['likes', 'comments']);
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
            'media' => $post->media->map(fn ($media) => [
                'id' => (string) $media->id,
                'url' => url("/api/community/posts/{$post->id}/media/{$media->id}"),
                'mime_type' => $media->mime_type,
                'width' => $media->width,
                'height' => $media->height,
                'position' => $media->position,
            ])->values(),
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
