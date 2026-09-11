<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Reset password | SyncroFit</title>
<style>:root{color-scheme:dark;font-family:Arial,sans-serif}body{margin:0;min-height:100vh;display:grid;place-items:center;background:#000;color:#fff}main{width:min(420px,calc(100% - 32px))}h1{margin-bottom:8px}p{color:#aaa;line-height:1.5}label{display:block;margin:18px 0 7px;font-weight:700}input{box-sizing:border-box;width:100%;padding:14px;border:1px solid #555;border-radius:10px;background:#202020;color:#fff;font-size:16px}button{width:100%;margin-top:24px;padding:14px;border:0;border-radius:999px;background:#fff;color:#000;font-size:16px;cursor:pointer}.error{color:#ff8a80}</style>
</head><body><main>
<h1>Reset your password</h1><p>Enter the email used by your SyncroFit account and choose a new password.</p>
@if ($errors->any())<p class="error">{{ $errors->first() }}</p>@endif
<form method="POST" action="{{ route('password.update') }}">@csrf
<input type="hidden" name="token" value="{{ $token }}">
<label for="email">Email</label><input id="email" name="email" type="email" autocomplete="email" value="{{ old('email', $email) }}" required>
<label for="password">New password</label><input id="password" name="password" type="password" autocomplete="new-password" minlength="8" maxlength="72" required>
<label for="password_confirmation">Confirm new password</label><input id="password_confirmation" name="password_confirmation" type="password" autocomplete="new-password" minlength="8" maxlength="72" required>
<button type="submit">Reset Password</button></form>
</main></body></html>
