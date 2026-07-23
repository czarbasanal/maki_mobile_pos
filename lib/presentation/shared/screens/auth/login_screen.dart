import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maki_mobile_pos/config/router/route_names.dart';
import 'package:maki_mobile_pos/core/errors/errors.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/utils/utils.dart';
import 'package:maki_mobile_pos/presentation/providers/providers.dart';
import 'package:maki_mobile_pos/presentation/shared/widgets/common/common_widgets.dart';

/// Login screen for user authentication.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;

    try {
      await context.runWithWaiting(
        () => ref.read(authActionsProvider).signIn(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
        message: 'Signing in…',
      );
      if (mounted) context.go(RoutePaths.dashboard);
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'An unexpected error occurred. Please try again.');
      }
    }
  }

  void _handleForgotPassword() {
    context.pushNamed(
      RouteNames.forgotPassword,
      extra: _emailController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 40),
                    if (_errorMessage != null) ...[
                      _buildErrorMessage(),
                      const SizedBox(height: 16),
                    ],
                    AppTextField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      labelText: 'Email',
                      prefixIcon: LucideIcons.mail,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofocus: true,
                      onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      labelText: 'Password',
                      prefixIcon: LucideIcons.lock,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleLogin(),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      text: 'Sign in',
                      onPressed: _handleLogin,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        onPressed: _handleForgotPassword,
                        style: TextButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // Brand-slate tile in both themes — the gold logo mark pops on the
        // dark backing whether the app is in light or dark mode.
        Container(
          width: 76,
          height: 76,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.brandSlate,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? const [
                    BoxShadow(
                      color: Color(0x73000000),
                      blurRadius: 20,
                      spreadRadius: -8,
                      offset: Offset(0, 10),
                    ),
                  ]
                : AppShadows.primaryButton,
          ),
          child: Image.asset(
            'assets/icon/maki_logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'MAKI POS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.4,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to your account',
          style: TextStyle(
            fontSize: 14,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.errorDark,
                fontSize: 13,
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close, size: 16, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'v1.0.0',
        style: TextStyle(
          fontSize: 11,
          color: AppColors.lightTextHint,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
