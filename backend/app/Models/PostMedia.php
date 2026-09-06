<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PostMedia extends Model
{
    protected $table = 'post_media';
    protected $fillable = ['post_id', 'disk', 'path', 'mime_type', 'size_bytes', 'width', 'height', 'position'];
    protected function casts(): array
    {
        return ['size_bytes' => 'integer', 'width' => 'integer', 'height' => 'integer', 'position' => 'integer'];
    }
    public function post() { return $this->belongsTo(Post::class); }
}
