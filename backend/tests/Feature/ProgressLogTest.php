<?php

namespace Tests\Feature;

use App\Models\ProgressLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProgressLogTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_create_list_and_delete_private_progress_log(): void
    {
        Storage::fake('local');
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $created = $this->post('/api/progress-logs', [
            'title' => 'Month one',
            'description' => 'Feeling stronger.',
            'weight_kg' => 72.4,
            'image' => UploadedFile::fake()->createWithContent(
                'progress.png',
                base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
            ),
        ])->assertCreated()->json('data');

        $this->getJson('/api/progress-logs')->assertOk()
            ->assertJsonPath('data.data.0.title', 'Month one');
        $log = ProgressLog::findOrFail($created['id']);
        Storage::disk('local')->assertExists($log->original_image_path);
        Storage::disk('local')->assertExists($log->display_image_path);
        $this->deleteJson("/api/progress-logs/{$log->id}")->assertOk();
        Storage::disk('local')->assertMissing($log->original_image_path);
        Storage::disk('local')->assertMissing($log->display_image_path);
    }

    public function test_other_users_cannot_access_log_or_image(): void
    {
        Storage::fake('local');
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $log = ProgressLog::create([
            'user_id' => $owner->id, 'title' => 'Private', 'description' => 'Private log',
            'weight_kg' => 70,
            'original_image_path' => 'progress-logs/original/private.jpg',
            'display_image_path' => 'progress-logs/display/private.jpg',
        ]);
        Sanctum::actingAs($other);
        $this->getJson("/api/progress-logs/{$log->id}")->assertNotFound();
        $this->get("/api/progress-logs/{$log->id}/image")->assertNotFound();
        $this->deleteJson("/api/progress-logs/{$log->id}")->assertNotFound();
    }

    public function test_progress_log_validation_rejects_invalid_fields(): void
    {
        Storage::fake('local');
        Sanctum::actingAs(User::factory()->create());
        $this->post('/api/progress-logs', [
            'title' => '', 'description' => str_repeat('x', 1001),
            'weight_kg' => 5, 'image' => UploadedFile::fake()->create('bad.txt', 1),
        ])->assertUnprocessable()->assertJsonValidationErrors(['title', 'description', 'weight_kg', 'image']);
    }
}
