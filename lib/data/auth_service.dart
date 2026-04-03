import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/models/app_models.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  Future<AuthResponse> signIn({
    required AuthMethod method,
    required String identifier,
    required String password,
  }) {
    switch (method) {
      case AuthMethod.email:
        return _client.auth.signInWithPassword(
          email: identifier,
          password: password,
        );
      case AuthMethod.phone:
        return _client.auth.signInWithPassword(
          phone: identifier,
          password: password,
        );
    }
  }

  Future<AuthResponse> signUp({
    required AuthMethod method,
    required String identifier,
    required String password,
    Map<String, dynamic>? data,
  }) {
    switch (method) {
      case AuthMethod.email:
        return _client.auth.signUp(
          email: identifier,
          password: password,
          data: data,
        );
      case AuthMethod.phone:
        return _client.auth.signUp(
          phone: identifier,
          password: password,
          data: data,
        );
    }
  }
}
