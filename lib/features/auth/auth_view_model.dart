import 'package:student_survivor/models/app_models.dart';

class AuthViewModel {
  final bool isLogin;
  final AuthMethod method;

  const AuthViewModel({
    required this.isLogin,
    required this.method,
  });

  AuthViewModel copyWith({
    bool? isLogin,
    AuthMethod? method,
  }) {
    return AuthViewModel(
      isLogin: isLogin ?? this.isLogin,
      method: method ?? this.method,
    );
  }

  factory AuthViewModel.initial() {
    return const AuthViewModel(
      isLogin: true,
      method: AuthMethod.email,
    );
  }
}
