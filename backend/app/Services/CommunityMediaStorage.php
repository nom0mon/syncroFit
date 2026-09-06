<?php

namespace App\Services;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

class CommunityMediaStorage
{
    public function disk(): string
    {
        return (string) env('COMMUNITY_MEDIA_DISK', 'local');
    }

    public function store(UploadedFile $photo, int $userId): array
    {
        $disk = $this->disk();
        $path = $photo->store("community/{$userId}/photos", $disk);
        [$width, $height] = getimagesize($photo->getRealPath()) ?: [null, null];
        return [
            'disk' => $disk,
            'path' => $path,
            'mime_type' => $photo->getMimeType() ?: 'application/octet-stream',
            'size_bytes' => $photo->getSize(),
            'width' => $width,
            'height' => $height,
        ];
    }

    public function delete(string $disk, string $path): void
    {
        Storage::disk($disk)->delete($path);
    }
}
