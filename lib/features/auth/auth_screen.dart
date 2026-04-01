import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
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
          final theme = Theme.of(context);
          return Stack(
            children: [
              const _AuthBackdrop(),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AuthHero(
                        isLogin: model.isLogin,
                        onToggle: presenter.toggleMode,
                      ),
                      const SizedBox(height: 20),
                      _AuthCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                model.isLogin
                                    ? 'Login to continue'
                                    : 'Create your account',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                model.isLogin
                                    ? 'Pick a method and jump back in.'
                                    : 'Start with email or phone in seconds.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.mutedInk,
                                ),
                              ),
                              const SizedBox(height: 16),
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
                                  prefixIcon: Icon(
                                    model.method == AuthMethod.email
                                        ? Icons.alternate_email
                                        : Icons.phone_iphone,
                                  ),
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
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
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
                              const SizedBox(height: 18),
                              const _InfoCallout(),
                              const SizedBox(height: 22),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: model.isSubmitting
                                      ? null
                                      : () {
                                          if (_formKey.currentState
                                                  ?.validate() !=
                                              true) {
                                            return;
                                          }
                                          presenter.submit(
                                            identifier: _identifierController
                                                .text
                                                .trim(),
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
                                          model.isLogin
                                              ? 'Continue'
                                              : 'Create Account',
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFEFF6FF),
            Color(0xFFECFEFF),
            AppColors.paper,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -70,
            right: -40,
            child: _GlowCircle(
              size: 220,
              color: Color(0x336366F1),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -30,
            child: _GlowCircle(
              size: 200,
              color: Color(0x3314B8A6),
            ),
          ),
          Positioned(
            top: 160,
            left: 30,
            child: _GlowCircle(
              size: 120,
              color: Color(0x220F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onToggle;

  const _AuthHero({
    required this.isLogin,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Student Survivor',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Study smarter, survive exams, and level up with AI.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: AppColors.mutedInk,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _FeatureTag(icon: Icons.auto_awesome, label: 'AI Notes'),
            _FeatureTag(icon: Icons.bolt, label: 'Quick Quizzes'),
            _FeatureTag(icon: Icons.gamepad, label: 'Game Loop'),
          ],
        ),
        const SizedBox(height: 18),
        _ModeToggle(isLogin: isLogin, onToggle: onToggle),
      ],
    );
  }
}

class _FeatureTag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureTag({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onToggle;

  const _ModeToggle({
    required this.isLogin,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          _ModeChip(
            label: 'Login',
            selected: isLogin,
            onTap: () {
              if (!isLogin) {
                onToggle();
              }
            },
          ),
          _ModeChip(
            label: 'Sign Up',
            selected: !isLogin,
            onTap: () {
              if (isLogin) {
                onToggle();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.ink : AppColors.mutedInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  final Widget child;

  const _AuthCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoCallout extends StatelessWidget {
  const _InfoCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentSoft.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 22, color: AppColors.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Complete your semester + subjects in Profile after login.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                  ),
            ),
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
    final theme = Theme.of(context);
    return SegmentedButton<AuthMethod>(
      segments: const [
        ButtonSegment(
          value: AuthMethod.email,
          label: Text('Email'),
          icon: Icon(Icons.mail_outline),
        ),
        ButtonSegment(
          value: AuthMethod.phone,
          label: Text('Phone'),
          icon: Icon(Icons.phone_android),
        ),
      ],
      selected: {selected},
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondary.withValues(alpha: 0.12);
          }
          return AppColors.surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.secondary;
          }
          return AppColors.mutedInk;
        }),
        side: WidgetStateProperty.resolveWith(
          (_) => const BorderSide(color: AppColors.outline),
        ),
        textStyle: WidgetStateProperty.all(
          theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      onSelectionChanged: (values) => onChanged(values.first),
    );
  }
}
