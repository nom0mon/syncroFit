<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('exercises')->orderBy('id')->each(function (object $exercise): void {
            DB::table('exercises')->where('id', $exercise->id)->update([
                'environments' => json_encode(
                    $exercise->equipment === 'bodyweight'
                        ? ['home', 'gym', 'outdoor']
                        : ['gym']
                ),
            ]);
        });
    }

    public function down(): void
    {
        DB::table('exercises')
            ->whereIn('equipment', ['dumbbell', 'kettlebell', 'resistance_band'])
            ->update(['environments' => json_encode(['home', 'gym'])]);
    }
};
