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

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onLogin() async {
    if (_loginFormKey.currentState!.validate()) {
      final auth = context.read<AuthProvider>();
      final success = await auth.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Login failed')),
        );
      }
    }
  }

  void _onSignUp() async {
    if (_signUpFormKey.currentState!.validate()) {
      final auth = context.read<AuthProvider>();
      final success = await auth.signUpWithEmail(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.error ?? 'Sign up failed')),
        );
      }
    }
  }

  void _onGoogleSignIn() async {
    final auth = context.read<AuthProvider>();
    final success = await auth.signInWithGoogle();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Google Sign-In failed')),
      );
    }
  }

  void _showForgotPassword() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXL)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Reset Password', style: AppTypography.headlineMedium),
            const SizedBox(height: 16),
            const CustomTextField(
              hintText: 'Email',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Send Reset Link',
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reset email sent!')),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.videocam_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Zuumeet',
                    textAlign: TextAlign.center,
                    style: AppTypography.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect with people around the world',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    height: 56,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusL),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: AppTypography.button,
                      tabs: const [
                        Tab(text: 'LOGIN'),
                        Tab(text: 'SIGN UP'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 400,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildLoginForm(),
                        _buildSignUpForm(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: AppTypography.caption),
                      ),
                      const Expanded(child: Divider(color: AppColors.border)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Continue with Google',
                    onPressed: _onGoogleSignIn,
                    outlined: true,
                    icon: Icons.g_mobiledata, // Placeholder for Google Icon
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'By signing up, you agree to our Terms of Service and Privacy Policy',
                    textAlign: TextAlign.center,
                    style: AppTypography.caption,
                  ),
                ],
              ),
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
            hintText: 'Email',
            prefixIcon: Icons.email_outlined,
            controller: _emailController,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            hintText: 'Password',
            prefixIcon: Icons.lock_outline,
            isPassword: true,
            controller: _passwordController,
            validator: Validators.password,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPassword,
              child: Text('Forgot Password?', style: AppTypography.button.copyWith(color: AppColors.primary, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Sign In',
            onPressed: _onLogin,
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpForm() {
    return Form(
      key: _signUpFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              hintText: 'Full Name',
              prefixIcon: Icons.person_outline,
              controller: _nameController,
              validator: Validators.name,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              hintText: 'Email',
              prefixIcon: Icons.email_outlined,
              controller: _emailController,
              validator: Validators.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              hintText: 'Password',
              prefixIcon: Icons.lock_outline,
              isPassword: true,
              controller: _passwordController,
              validator: Validators.password,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              hintText: 'Confirm Password',
              prefixIcon: Icons.lock_outline,
              isPassword: true,
              controller: _confirmPasswordController,
              validator: (v) => Validators.confirmPassword(v, _passwordController.text),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Create Account',
              onPressed: _onSignUp,
            ),
          ],
        ),
      ),
    );
  }
}
