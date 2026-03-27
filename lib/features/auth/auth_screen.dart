import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/features/auth/auth_presenter.dart';
import 'package:student_survivor/features/auth/auth_view_model.dart';
import 'package:student_survivor/features/shell/app_shell.dart';
import 'package:student_survivor/models/app_models.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState
    extends PresenterState<AuthScreen, AuthView, AuthPresenter>
    implements AuthView {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  AuthPresenter createPresenter() => AuthPresenter();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void goToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<AuthViewModel>(
        valueListenable: presenter.state,
        builder: (context, model, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(isLogin: model.isLogin, onToggle: presenter.toggleMode),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model.isLogin ? 'Welcome back' : 'Create your account',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        _AuthMethodSelector(
                          selected: model.method,
                          onChanged: presenter.setAuthMethod,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _identifierController,
                          keyboardType: model.method == AuthMethod.email
                              ? TextInputType.emailAddress
                              : TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: model.method == AuthMethod.email
                                ? 'Email'
                                : 'Phone',
                          ),
                          validator: (value) {
                            final input = value?.trim() ?? '';
                            if (input.isEmpty) {
                              return model.method == AuthMethod.email
                                  ? 'Email is required'
                                  : 'Phone is required';
                            }
                            if (model.method == AuthMethod.email &&
                                !input.contains('@')) {
                              return 'Enter a valid email';
                            }
                            if (model.method == AuthMethod.phone &&
                                input.length < 8) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password'),
                          validator: (value) {
                            final input = value?.trim() ?? '';
                            if (input.isEmpty) {
                              return 'Password is required';
                            }
                            if (input.length < 6) {
                              return 'Minimum 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        AppCard(
                          color: AppColors.accentSoft,
                          child: Row(
                            children: [
                              const Icon(Icons.auto_awesome, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Complete your semester + subjects in Profile after login.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: model.isSubmitting
                                ? null
                                : () {
                                    if (_formKey.currentState?.validate() !=
                                        true) {
                                      return;
                                    }
                                    presenter.submit(
                                      identifier:
                                          _identifierController.text.trim(),
                                      password: _passwordController.text,
                                    );
                                  },
                            child: model.isSubmitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    model.isLogin ? 'Continue' : 'Create Account',
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onToggle;

  const _Header({
    required this.isLogin,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.secondary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Student Survivor',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Build momentum for exams with AI + game loops.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Login'),
                selected: isLogin,
                onSelected: (_) {
                  if (!isLogin) {
                    onToggle();
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Sign Up'),
                selected: !isLogin,
                onSelected: (_) {
                  if (isLogin) {
                    onToggle();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthMethodSelector extends StatelessWidget {
  final AuthMethod selected;
  final ValueChanged<AuthMethod> onChanged;

  const _AuthMethodSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AuthMethod>(
      segments: const [
        ButtonSegment(value: AuthMethod.email, label: Text('Email')),
        ButtonSegment(value: AuthMethod.phone, label: Text('Phone')),
      ],
      selected: {selected},
      onSelectionChanged: (values) => onChanged(values.first),
    );
  }
}
