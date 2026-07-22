import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';

/// Register screen matching Figma "Sign Up 1" design:
/// Back arrow + logo in top row, centered "Sign Up" title,
/// subtitle, Username/Password/Confirm Password/Email fields,
/// "Next" button, copyright footer.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authStateProvider.notifier).register(
          _nameController.text.trim(),
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
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        context.go(RouteNames.profileSetup);
      }
    });

    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar with back button and logo
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => context.go(RouteNames.login),
                      icon: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.xl),

                        // Title
                        Text(
                          'Sign Up',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // Subtitle
                        Text(
                          'This will serve as your sign in credentials',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.grey600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Username field
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'E-mail',
                          ),
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          textInputAction: TextInputAction.next,
                          maxLength: 50,
                          validator: validateName,
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
                          textInputAction: TextInputAction.next,
                          validator: validatePassword,
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Confirm Password field
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: const InputDecoration(
                            hintText: 'Confirm Password',
                          ),
                          style: const TextStyle(color: Colors.black),
                          cursorColor: Colors.black,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          validator: (value) => validatePasswordMatch(
                            _passwordController.text,
                            value,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Email field
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

                        // Next button
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
                                : const Text('Next'),
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
