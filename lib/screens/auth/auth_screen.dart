import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart' as apple;

import '../../theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthViewModel _viewModel = AuthViewModel();
  bool _appleAvailable = false;
  static const double _loginButtonHeight = 56.0;

  @override
  void initState() {
    super.initState();
    _viewModel.init(
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
    _loadAppleAvailability();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showAppleButton = _appleAvailable;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFAD4D4), Color(0xFFF5E6E0), Color(0xFFE8F4F8)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Logo
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // App Name
                const Text(
                  'MemHarbor',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '소중한 추억을 연결합니다',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.secondary.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(flex: 2),
                // Login Buttons
                if (_viewModel.isLoading)
                  const CircularProgressIndicator(color: AppColors.secondary)
                else ...[
                  if (showAppleButton)
                    _buildLoginButton(
                      context,
                      text: 'Apple로 계속하기',
                      backgroundColor: Colors.black,
                      textColor: Colors.white,
                      onPressed: _handleAppleLogin,
                      leading: const Text(
                        '',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (showAppleButton) const SizedBox(height: 12),
                  _buildLoginButton(
                    context,
                    icon: Icons.g_mobiledata_rounded,
                    text: 'Google로 계속하기',
                    backgroundColor: Colors.white,
                    textColor: AppColors.textPrimary,
                    onPressed: _handleGoogleLogin,
                  ),
                ],
                const Spacer(),
                // Terms
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Text(
                    '계속 진행하면 서비스 이용약관 및\n개인정보 처리방침에 동의하는 것으로 간주됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(
    BuildContext context, {
    required String text,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onPressed,
    Widget? leading,
    IconData? icon,
    double fontSize = 16,
  }) {
    assert(
      leading != null || icon != null,
      'Either leading or icon must be provided.',
    );
    return SizedBox(
      width: double.infinity,
      height: _loginButtonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) leading else Icon(icon, size: 24),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAppleAvailability() async {
    if (kIsWeb) return;
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.macOS) {
      return;
    }

    final available = await apple.SignInWithApple.isAvailable();
    if (!mounted) return;
    setState(() => _appleAvailable = available);
  }

  Future<void> _handleAppleLogin() async {
    final result = await _viewModel.signInWithApple();
    if (!mounted) return;

    if (result.errorMessage != null) {
      _showErrorSnackBar(result.errorMessage!);
      return;
    }

    if (result.nextStep == AuthNextStep.main) {
      Navigator.of(context).pushReplacementNamed('/main');
    } else if (result.nextStep == AuthNextStep.onboarding) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  Future<void> _handleGoogleLogin() async {
    final result = await _viewModel.signInWithGoogle();
    if (!mounted) return;

    if (result.errorMessage != null) {
      _showErrorSnackBar(result.errorMessage!);
      return;
    }

    if (result.nextStep == AuthNextStep.main) {
      Navigator.of(context).pushReplacementNamed('/main');
    } else if (result.nextStep == AuthNextStep.onboarding) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade400),
    );
  }
}
