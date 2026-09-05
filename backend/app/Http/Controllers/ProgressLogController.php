<?php

namespace App\Http\Controllers;

use App\Models\ProgressLog;
use App\Services\ProgressImageStorage;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class ProgressLogController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $logs = ProgressLog::where('user_id', $request->user()->id)
            ->latest('created_at')
            ->paginate(min(max((int) $request->query('per_page', 20), 1), 50));

        return response()->json(['success' => true, 'data' => $logs]);
    }

    public function store(Request $request, ProgressImageStorage $images): JsonResponse
    {
        $validated = $request->validate([
            'title' => ['required', 'string', 'max:100'],
            'description' => ['required', 'string', 'max:1000'],
            'weight_kg' => ['required', 'numeric', 'between:20,500'],
            'image' => ['required', 'file', 'image', 'mimes:jpeg,png,webp', 'max:5120', 'dimensions:max_width=4096,max_height=4096'],
        ]);

        $paths = $images->store($request->file('image'), (int) $request->user()->id);
        $log = ProgressLog::create([
            'user_id' => $request->user()->id,
            'title' => trim($validated['title']),
            'description' => trim($validated['description']),
            'weight_kg' => $validated['weight_kg'],
            ...$paths,
        ]);

        return response()->json(['success' => true, 'data' => $log], 201);
    }

    public function show(Request $request, ProgressLog $progressLog): JsonResponse
    {
        $this->owned($request, $progressLog);
        return response()->json(['success' => true, 'data' => $progressLog]);
    }

    public function image(Request $request, ProgressLog $progressLog): BinaryFileResponse
    {
        $this->owned($request, $progressLog);
        abort_unless(Storage::disk('local')->exists($progressLog->display_image_path), 404);
        return response()->file(Storage::disk('local')->path($progressLog->display_image_path));
    }

    public function destroy(Request $request, ProgressLog $progressLog, ProgressImageStorage $images): JsonResponse
    {
        $this->owned($request, $progressLog);
        $images->delete($progressLog->original_image_path, $progressLog->display_image_path);
        $progressLog->delete();
        return response()->json(['success' => true, 'data' => null]);
    }

    private function owned(Request $request, ProgressLog $log): void
    {
        abort_unless((int) $log->user_id === (int) $request->user()->id, 404);
    }
}
