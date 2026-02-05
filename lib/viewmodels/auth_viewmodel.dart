import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';

enum AuthNextStep { main, onboarding }

class AuthLoginResult {
  final AuthNextStep? nextStep;
  final String? errorMessage;

  const AuthLoginResult({this.nextStep, this.errorMessage});
}

class AuthViewModel {
  bool isLoading = false;
  void Function()? _onChanged;

  void init({required void Function() onChanged}) {
    _onChanged = onChanged;
  }

  void dispose() {
    _onChanged = null;
  }

  Future<AuthLoginResult> signInWithGoogle() async {
    if (isLoading) return const AuthLoginResult();
    isLoading = true;
    _onChanged?.call();

    try {
      final userCredential = await AuthService.instance.signInWithGoogle();
      if (userCredential == null) {
        return const AuthLoginResult(errorMessage: '로그인에 실패했습니다.');
      }

      final userExists =
          await UserService.instance.userExists(userCredential.user!.uid);
      return AuthLoginResult(
        nextStep: userExists ? AuthNextStep.main : AuthNextStep.onboarding,
      );
    } catch (e) {
      return AuthLoginResult(errorMessage: 'Google 로그인에 실패했습니다: $e');
    } finally {
      isLoading = false;
      _onChanged?.call();
    }
  }

  Future<AuthLoginResult> signInWithApple() async {
    if (isLoading) return const AuthLoginResult();
    isLoading = true;
    _onChanged?.call();

    try {
      final userCredential = await AuthService.instance.signInWithApple();
      if (userCredential == null) {
        return const AuthLoginResult(errorMessage: '로그인에 실패했습니다.');
      }

      final userExists =
          await UserService.instance.userExists(userCredential.user!.uid);
      return AuthLoginResult(
        nextStep: userExists ? AuthNextStep.main : AuthNextStep.onboarding,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const AuthLoginResult();
      }
      return AuthLoginResult(
        errorMessage:
            'Apple 로그인에 실패했습니다: ${e.code.name} ${e.message ?? ''}'.trim(),
      );
    } catch (e) {
      return AuthLoginResult(errorMessage: 'Apple 로그인에 실패했습니다: $e');
    } finally {
      isLoading = false;
      _onChanged?.call();
    }
  }
}
