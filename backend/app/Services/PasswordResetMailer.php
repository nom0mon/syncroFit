<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Password;

class PasswordResetMailer
{
    public function send(string $email): void
    {
        $user = User::where('email', $email)->first();
        if ($user === null) return;

        $apiKey = (string) config('services.brevo.key');
        if ($apiKey === '') throw new \RuntimeException('BREVO_API_KEY is not configured.');

        $token = Password::broker()->createToken($user);
        $resetUrl = route('password.reset', ['token' => $token, 'email' => $user->email]);
        $safeUrl = htmlspecialchars($resetUrl, ENT_QUOTES, 'UTF-8');

        Http::withHeaders(['api-key' => $apiKey])->acceptJson()->timeout(12)
            ->post('https://api.brevo.com/v3/smtp/email', [
                'sender' => ['name' => (string) config('mail.from.name', 'SyncroFit'), 'email' => (string) config('mail.from.address')],
                'to' => [['email' => $user->email, 'name' => $user->username]],
                'subject' => 'Reset your SyncroFit password',
                'htmlContent' => '<h1>Reset your password</h1><p>We received a password reset request for your SyncroFit account.</p><p><a href="'.$safeUrl.'">Reset Password</a></p><p>This link expires in 60 minutes. If you did not request it, no action is required.</p>',
            ])->throw();
    }
}
