<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // SyncroFit uses the file cache store; no database cache tables needed.
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // No database objects are created by this migration.
    }
};
