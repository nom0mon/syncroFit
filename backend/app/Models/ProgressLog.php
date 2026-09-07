<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProgressLog extends Model
{
    use HasFactory;

    protected $fillable = ['user_id', 'title', 'description', 'weight_kg', 'original_image_path', 'display_image_path'];

    protected $hidden = ['original_image_path', 'display_image_path'];

    protected function casts(): array
    {
        return ['weight_kg' => 'float'];
    }

    protected $appends = ['image_url'];

    public function getImageUrlAttribute(): string
    {
        return rtrim((string) config('app.url'), '/')."/api/progress-logs/{$this->id}/image";
    }
}
