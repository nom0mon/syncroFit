<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class ProgressImageStorage
{
    public function disk(): string
    {
        return (string) config('filesystems.progress_media_disk', 'local');
    }

    public function store(UploadedFile $image, int $userId): array
    {
        $disk = $this->disk();
        $original = $image->store("progress-logs/{$userId}/original", $disk);
        $display = $image->store("progress-logs/{$userId}/display", $disk);
        return ['original_image_path' => $original, 'display_image_path' => $display];
    }

    public function delete(string $original, string $display): void
    {
        Storage::disk($this->disk())->delete([$original, $display]);
    }
}
