<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('sessions');
        Schema::dropIfExists('cache_locks');
        Schema::dropIfExists('cache');
    }

    public function down(): void
    {
        // These optional framework tables are intentionally not recreated.
        // SyncroFit uses SESSION_DRIVER=file and CACHE_STORE=file.
    }
};
