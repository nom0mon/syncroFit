<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('username', 30)->nullable()->after('last_name');
        });

        DB::table('users')->orderBy('id')->get()->each(function ($user): void {
            $base = Str::of(trim("{$user->first_name}.{$user->last_name}"))
                ->ascii()
                ->lower()
                ->replaceMatches('/[^a-z0-9._]+/', '.')
                ->trim('.')
                ->limit(24, '')
                ->toString();
            $base = strlen($base) >= 3 ? $base : 'user';
            $candidate = $base;
            $suffix = 2;

            while (DB::table('users')->where('username', $candidate)->exists()) {
                $candidate = substr($base, 0, 30 - strlen((string) $suffix) - 1).'.'.$suffix;
                $suffix++;
            }

            DB::table('users')->where('id', $user->id)->update(['username' => $candidate]);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->unique('username');
            $table->text('first_name')->change();
            $table->text('last_name')->change();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['username']);
            $table->dropColumn('username');
            $table->string('first_name')->change();
            $table->string('last_name')->change();
        });
    }
};
