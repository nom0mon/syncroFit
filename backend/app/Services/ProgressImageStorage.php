<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class ProgressImageStorage
{
    public function store(UploadedFile $image, int $userId): array
    {
        $original = $image->store("progress-logs/{$userId}/original", 'local');
        $display = $image->store("progress-logs/{$userId}/display", 'local');
        return ['original_image_path' => $original, 'display_image_path' => $display];
    }

    public function delete(string $original, string $display): void
    {
        Storage::disk('local')->delete([$original, $display]);
    }
}
