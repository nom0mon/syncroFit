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

/// Login screen matching the Figma design while remaining usable across the
/// supported Android viewport, cutout, keyboard, and text-scale matrix.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const double _maxFormWidth = 480;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authStateProvider.notifier).login(
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
    });

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        body: SafeScrollableForm(
          verticalPadding: AppSpacing.lg,
          bottomAction: keyboardIsVisible ? null : const _AuthFooter(),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxFormWidth),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xxl),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'SyncroFit',
                      style:
                          Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(hintText: 'E-mail'),
                      style: const TextStyle(color: Colors.black),
                      cursorColor: Colors.black,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: validateEmail,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(hintText: 'Password'),
                      style: const TextStyle(color: Colors.black),
                      cursorColor: Colors.black,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: validatePassword,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('forgot-password-link'),
                        onPressed: () => context.go(RouteNames.forgotPassword),
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: ElevatedButton(
                        key: const Key('login-submit'),
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
                            : const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.grey300)),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                          child: Text(
                            'or',
                            style: TextStyle(color: AppColors.grey600),
                          ),
                        ),
                        Expanded(child: Divider(color: AppColors.grey300)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: ElevatedButton(
                        onPressed: () => context.go(RouteNames.register),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.grey200,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Sign Up'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthFooter extends StatelessWidget {
  const _AuthFooter();

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
