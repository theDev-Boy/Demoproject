import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../config/app_dimensions.dart';
import '../config/app_typography.dart';
import '../providers/auth_provider.dart';
import '../utils/validators.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/loading_overlay.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  final _signUpNameCtrl = TextEditingController();
  final _signUpEmailCtrl = TextEditingController();
  final _signUpPasswordCtrl = TextEditingController();
  final _signUpConfirmCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signUpNameCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _signUpPasswordCtrl.dispose();
    _signUpConfirmCtrl.dispose();
    super.dispose();
  }

  void _onLogin() async {
    if (_loginFormKey.currentState!.validate()) {
      final auth = context.read<AuthProvider>();
      final success = await auth.signInWithEmail(
        email: _loginEmailCtrl.text.trim(),
        password: _loginPasswordCtrl.text,
      );
      if (!success && mounted) {
        _showError(auth.error ?? 'Login failed');
      }
    }
  }

  void _onSignUp() async {
    if (_signUpFormKey.currentState!.validate()) {
      final auth = context.read<AuthProvider>();
      final success = await auth.signUpWithEmail(
        name: _signUpNameCtrl.text.trim(),
        email: _signUpEmailCtrl.text.trim(),
        password: _signUpPasswordCtrl.text,
      );
      if (!success && mounted) {
        _showError(auth.error ?? 'Sign up failed');
      }
    }
  }

  void _onGoogleSignIn() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (!success && mounted) {
      _showError(auth.error ?? 'Google Sign-In failed');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusM)),
      ),
    );
  }

  void _showForgotPassword() {
    final resetEmailCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXL)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reset Password', style: AppTypography.headlineMedium),
            const SizedBox(height: 8),
            Text('Enter your email and we\'ll send a reset link.', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            CustomTextField(
              hintText: 'Email address',
              prefixIcon: Icons.email_outlined,
              controller: resetEmailCtrl,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Send Reset Link',
              height: 56,
              onPressed: () async {
                if (resetEmailCtrl.text.trim().isNotEmpty) {
                  final auth = context.read<AuthProvider>();
                  await auth.sendPasswordReset(resetEmailCtrl.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Check your email for a reset link!')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenH = MediaQuery.sizeOf(context).height;

    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth > 500 ? constraints.maxWidth * 0.15 : 24,
                    vertical: 12,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: screenH * 0.04),

                        // LOGO
                        Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutBack,
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 40),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Welcome to Zuumeet',
                          textAlign: TextAlign.center,
                          style: AppTypography.displayMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Connect with people around the world',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),

                        const SizedBox(height: 32),

                        // TAB BAR
                        Container(
                          height: 52,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2A2A2A) : AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: isDark ? const Color(0xFF3A3A3A) : Colors.white,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                              boxShadow: [
                                if (!isDark)
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            labelColor: AppColors.primary,
                            unselectedLabelColor: AppColors.textSecondary,
                            labelStyle: AppTypography.button.copyWith(fontSize: 15),
                            dividerColor: Colors.transparent,
                            tabs: const [
                              Tab(text: 'LOGIN'),
                              Tab(text: 'SIGN UP'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // TAB VIEWS — use AnimatedSize for smoothness
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: IndexedStack(
                            index: _tabController.index,
                            children: [
                              _buildLoginForm(),
                              _buildSignUpForm(),
                            ],
                          ),
                        ),

                        // OR Divider
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text('OR', style: AppTypography.caption.copyWith(fontSize: 13)),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                        ),

                        // GOOGLE BUTTON — LARGE
                        SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _onGoogleSignIn,
                            icon: Image.network(
                              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                              width: 22,
                              height: 22,
                              errorBuilder: (_, e, s) => const Icon(Icons.g_mobiledata, size: 26),
                            ),
                            label: Text(
                              'Continue with Google',
                              style: AppTypography.button.copyWith(fontSize: 16, color: isDark ? Colors.white : AppColors.textPrimary),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: isDark ? Colors.white24 : AppColors.border, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        Text(
                          'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(height: 1.5),
                        ),
                        SizedBox(height: screenH * 0.03),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (isLoading) const LoadingOverlay(),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            hintText: 'Email address',
            prefixIcon: Icons.email_outlined,
            controller: _loginEmailCtrl,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            hintText: 'Password',
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            controller: _loginPasswordCtrl,
            validator: Validators.password,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPassword,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8)),
              child: Text(
                'Forgot Password?',
                style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          CustomButton(
            text: 'Sign In',
            height: 56,
            onPressed: _onLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Form(
      key: _signUpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomTextField(
            hintText: 'Full Name',
            prefixIcon: Icons.person_outline,
            controller: _signUpNameCtrl,
            validator: Validators.name,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            hintText: 'Email address',
            prefixIcon: Icons.email_outlined,
            controller: _signUpEmailCtrl,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            hintText: 'Password',
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            controller: _signUpPasswordCtrl,
            validator: Validators.password,
          ),
          const SizedBox(height: 14),
          CustomTextField(
            hintText: 'Confirm Password',
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            controller: _signUpConfirmCtrl,
            validator: (v) => Validators.confirmPassword(v, _signUpPasswordCtrl.text),
          ),
          const SizedBox(height: 20),
          CustomButton(
            text: 'Create Account',
            height: 56,
            onPressed: _onSignUp,
          ),
        ],
      ),
    );
  }
}
