<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Reset password | SyncroFit</title>
<style>
:root{color-scheme:dark;font-family:Arial,sans-serif}body{margin:0;min-height:100vh;display:grid;place-items:center;background:#000;color:#fff}main{width:min(420px,calc(100% - 32px))}h1{margin-bottom:8px}p{color:#aaa;line-height:1.5}label{display:block;margin:18px 0 7px;font-weight:700}.field{position:relative}.field input{padding-right:76px}input{box-sizing:border-box;width:100%;padding:14px;border:1px solid #555;border-radius:10px;background:#202020;color:#fff;font-size:16px}.toggle{position:absolute;right:8px;top:50%;transform:translateY(-50%);border:0;background:transparent;color:#ddd;padding:8px;cursor:pointer}.submit{width:100%;margin-top:24px;padding:14px;border:0;border-radius:999px;background:#fff;color:#000;font-size:16px;cursor:pointer}.error{color:#ff8a80}.requirements{font-size:13px;color:#aaa;margin-top:8px}
</style>
</head><body><main>
<h1>Reset your password</h1><p>Enter the email used by your SyncroFit account and choose a new password.</p>
@if ($errors->any())<p class="error" role="alert">{{ $errors->first() }}</p>@endif
<form method="POST" action="{{ route('password.update') }}">@csrf
<input type="hidden" name="token" value="{{ $token }}">
<label for="email">Email</label><input id="email" name="email" type="email" autocomplete="email" value="{{ old('email', $email) }}" required>
<label for="password">New password</label><div class="field"><input id="password" name="password" type="password" autocomplete="new-password" minlength="8" maxlength="72" required><button class="toggle" type="button" data-target="password" aria-label="Show new password">Show</button></div>
<p class="requirements">Use 8+ characters with uppercase, lowercase, a number, and a special character such as ! @ # $ % &amp; *.</p>
<label for="password_confirmation">Confirm new password</label><div class="field"><input id="password_confirmation" name="password_confirmation" type="password" autocomplete="new-password" minlength="8" maxlength="72" required><button class="toggle" type="button" data-target="password_confirmation" aria-label="Show password confirmation">Show</button></div>
<button class="submit" type="submit">Reset Password</button></form>
</main><script>document.querySelectorAll('.toggle').forEach(function(button){button.addEventListener('click',function(){var input=document.getElementById(button.dataset.target);var hidden=input.type==='password';input.type=hidden?'text':'password';button.textContent=hidden?'Hide':'Show';button.setAttribute('aria-label',(hidden?'Hide ':'Show ')+(button.dataset.target==='password'?'new password':'password confirmation'));});});</script></body></html>
