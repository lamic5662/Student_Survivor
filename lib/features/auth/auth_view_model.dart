import 'package:student_survivor/models/app_models.dart';

class AuthViewModel {
  final bool isLogin;
  final AuthMethod method;
  final bool isSubmitting;

  const AuthViewModel({
    required this.isLogin,
    required this.method,
    required this.isSubmitting,
  });

  AuthViewModel copyWith({
    bool? isLogin,
    AuthMethod? method,
    bool? isSubmitting,
  }) {
    return AuthViewModel(
      isLogin: isLogin ?? this.isLogin,
      method: method ?? this.method,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  factory AuthViewModel.initial() {
    return const AuthViewModel(
      isLogin: true,
      method: AuthMethod.email,
      isSubmitting: false,
    );
  }
}
