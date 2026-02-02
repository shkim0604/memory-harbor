import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                _buildLoginButton(
                  context,
                  icon: Icons.g_mobiledata_rounded,
                  text: 'Google로 계속하기',
                  backgroundColor: Colors.white,
                  textColor: AppColors.textPrimary,
                  onPressed: () => _handleGoogleLogin(context),
                ),
                const SizedBox(height: 16),
                _buildLoginButton(
                  context,
                  icon: Icons.apple,
                  text: 'Apple로 계속하기',
                  backgroundColor: Colors.black,
                  textColor: Colors.white,
                  onPressed: () => _handleAppleLogin(context),
                ),
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
    required IconData icon,
    required String text,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
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
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _handleGoogleLogin(BuildContext context) {
    // TODO: Implement Google login
    _navigateToHome(context);
  }

  void _handleAppleLogin(BuildContext context) {
    // TODO: Implement Apple login
    _navigateToHome(context);
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushReplacementNamed('/main');
  }
}
