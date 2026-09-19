import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/safe_layout.dart';
import '../providers/auth_provider.dart';

/// Registration screen matching the Figma design while remaining usable across
/// the supported Android viewport, cutout, keyboard, and text-scale matrix.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const double _maxFormWidth = 480;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authStateProvider.notifier).register(
          _usernameController.text.trim().toLowerCase(),
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final keyboardIsVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
        ref.read(authStateProvider.notifier).clearError();
      }
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        context.go(RouteNames.profileSetup);
      }
    });

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        body: SafeScrollableForm(
          verticalPadding: AppSpacing.sm,
          bottomAction: keyboardIsVisible ? null : const _RegisterFooter(),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxFormWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Back to sign in',
                        onPressed: () => context.go(RouteNames.login),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.black,
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign Up',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'This will serve as your sign in credentials',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.grey600,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            hintText: 'Username',
                          ),
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          textInputAction: TextInputAction.next,
                          maxLength: 30,
                          validator: validateUsername,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _passwordController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                            ),
                          ),
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          validator: validatePassword,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _PasswordStrengthIndicator(
                          password: _passwordController.text,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            hintText: 'Confirm Password',
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirmation
                                  ? 'Show confirmation'
                                  : 'Hide confirmation',
                              onPressed: () => setState(() =>
                                  _obscureConfirmation = !_obscureConfirmation),
                              icon: Icon(_obscureConfirmation
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                            ),
                          ),
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          obscureText: _obscureConfirmation,
                          textInputAction: TextInputAction.next,
                          validator: (value) => validatePasswordMatch(
                            _passwordController.text,
                            value,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            hintText: 'Email Address',
                          ),
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          validator: validateEmail,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: ElevatedButton(
                            key: const Key('register-submit'),
                            onPressed: authState.isLoading ? null : _submit,
                            child: authState.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Next'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final score = passwordStrengthScore(password);
    final label = password.isEmpty
        ? 'Password requirements'
        : score <= 2
            ? 'Weak password'
            : score < 5
                ? 'Moderate password'
                : 'Strong password';
    final color = score == 5
        ? Colors.green.shade700
        : score >= 3
            ? Colors.orange.shade800
            : Colors.red.shade700;
    final requirements = <(String, bool)>[
      ('8 or more characters', password.length >= 8),
      (
        'Uppercase and lowercase letters',
        RegExp(r'[A-Z]').hasMatch(password) &&
            RegExp(r'[a-z]').hasMatch(password)
      ),
      ('At least one number', RegExp(r'[0-9]').hasMatch(password)),
      (
        'Special character: ! @ # \$ % ^ & * and similar',
        RegExp(r'[!@#$%^&*()_+\-=\[\]{};:\\|,.<>\/?]').hasMatch(password)
      ),
    ];

    return Semantics(
      liveRegion: true,
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: color)),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(value: score / 5, color: color),
          const SizedBox(height: AppSpacing.xs),
          ...requirements.map((item) => Text(
                '${item.$2 ? '✓' : '○'} ${item.$1}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          item.$2 ? Colors.green.shade700 : AppColors.grey600,
                    ),
              )),
        ],
      ),
    );
  }
}

class _RegisterFooter extends StatelessWidget {
  const _RegisterFooter();

  @override
  Widget build(BuildContext context) {
    return Text(
      'SyncroFit\nCopyright ©2026',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.grey500,
          ),
      textAlign: TextAlign.center,
    );
  }
}
