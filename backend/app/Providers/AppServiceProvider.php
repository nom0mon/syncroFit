<?php

namespace App\Providers;

use App\Exceptions\ApiExceptionHandler;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->singleton(ApiExceptionHandler::class, function ($app) {
            return new ApiExceptionHandler();
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}
