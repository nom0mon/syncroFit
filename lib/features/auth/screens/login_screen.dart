import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

/// Login screen matching the Figma design:
/// Centered logo + "SyncroFit" title, username/password fields,
/// Sign In button, "or" divider, Sign Up button, copyright footer.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 80),

                        // Logo
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

                        // App name
                        Text(
                          'SyncroFit',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),

                        // Username field
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            hintText: 'E-mail',
                          ),
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: validateEmail,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            hintText: 'Password',
                          ),
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          validator: validatePassword,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Sign In button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
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

                        // "or" divider
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

                        // Sign Up button (lighter)
                        SizedBox(
                          height: 52,
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

              // Copyright footer — hidden when keyboard is open
              if (MediaQuery.of(context).viewInsets.bottom == 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Text(
                    'SyncroFit\nCopyright ©2026',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.grey500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
