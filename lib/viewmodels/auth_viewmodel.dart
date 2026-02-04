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
}
