<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const SOURCE = 'https://github.com/yuhonas/free-exercise-db';

    public function up(): void
    {
        Schema::table('exercises', function (Blueprint $table) {
            $table->json('environments')->nullable()->after('equipment');
            $table->string('verification_status')->default('catalog_cross_checked')->after('environments');
            $table->string('source_reference')->nullable()->after('verification_status');
        });

        DB::table('exercises')->orderBy('id')->each(function (object $exercise): void {
            DB::table('exercises')->where('id', $exercise->id)->update([
                'environments' => json_encode($this->environmentsFor((string) $exercise->equipment)),
                'source_reference' => self::SOURCE,
            ]);
        });
    }

    public function down(): void
    {
        Schema::table('exercises', function (Blueprint $table) {
            $table->dropColumn(['environments', 'verification_status', 'source_reference']);
        });
    }

    private function environmentsFor(string $equipment): array
    {
        return match ($equipment) {
            'bodyweight' => ['home', 'gym', 'outdoor'],
            'dumbbell', 'kettlebell', 'resistance_band' => ['home', 'gym'],
            default => ['gym'],
        };
    }
};
