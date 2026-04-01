import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/features/auth/auth_presenter.dart';
import 'package:student_survivor/features/auth/auth_view_model.dart';
import 'package:student_survivor/models/app_models.dart';

class AdminAuthScreen extends StatefulWidget {
  final VoidCallback onLoggedIn;

  const AdminAuthScreen({super.key, required this.onLoggedIn});

  @override
  State<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState
    extends PresenterState<AdminAuthScreen, AuthView, AuthPresenter>
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
    widget.onLoggedIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<AuthViewModel>(
        valueListenable: presenter.state,
        builder: (context, model, _) {
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0B1020),
                  Color(0xFF111827),
                  Color(0xFF1F2937),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                const _BackdropOrbs(),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 68,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _HeroHeader(
                                isLogin: model.isLogin,
                                onToggle: presenter.toggleMode,
                              ),
                              const SizedBox(height: 24),
                              _AdminAuthCard(
                                formKey: _formKey,
                                model: model,
                                identifierController: _identifierController,
                                passwordController: _passwordController,
                                onSubmit: () {
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
                                onMethodChanged: presenter.setAuthMethod,
                              ),
                              const SizedBox(height: 18),
                              const _AdminFooterNote(),
                            ],
                          ),
                        ),
                      );
                    },
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

class _BackdropOrbs extends StatelessWidget {
  const _BackdropOrbs();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -40,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.2),
            ),
          ),
        ),
        Positioned(
          bottom: -40,
          left: -20,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withValues(alpha: 0.2),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onToggle;

  const _HeroHeader({
    required this.isLogin,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.8),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Admin Studio', style: titleStyle),
        const SizedBox(height: 8),
        Text(
          'Control notes, quizzes, and announcements with confidence.',
          style: subtitleStyle,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _MetaChip(
              icon: Icons.shield_moon_outlined,
              label: 'Secure Access',
            ),
            const SizedBox(width: 10),
            _MetaChip(
              icon: Icons.auto_graph,
              label: 'Live Insights',
            ),
          ],
        ),
        const SizedBox(height: 20),
        _ModeToggle(
          isLogin: isLogin,
          onToggle: onToggle,
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
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

  const _ModeToggle({required this.isLogin, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeToggleButton(
              label: 'Login',
              isActive: isLogin,
              onTap: isLogin ? null : onToggle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeToggleButton(
              label: 'Sign up',
              isActive: !isLogin,
              onTap: isLogin ? onToggle : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggleButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _ModeToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isActive ? AppColors.ink : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminAuthCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final AuthViewModel model;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final VoidCallback onSubmit;
  final ValueChanged<AuthMethod> onMethodChanged;

  const _AdminAuthCard({
    required this.formKey,
    required this.model,
    required this.identifierController,
    required this.passwordController,
    required this.onSubmit,
    required this.onMethodChanged,
  });

  @override
  Widget build(BuildContext context) {
    final heading = model.isLogin ? 'Admin Login' : 'Create Admin Account';
    final subheading = model.isLogin
        ? 'Sign in to manage content.'
        : 'Create an admin profile to publish content.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subheading,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.mutedInk),
            ),
            const SizedBox(height: 16),
            _AuthMethodSelector(
              selected: model.method,
              onChanged: onMethodChanged,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: identifierController,
              keyboardType: model.method == AuthMethod.email
                  ? TextInputType.emailAddress
                  : TextInputType.phone,
              decoration: InputDecoration(
                labelText:
                    model.method == AuthMethod.email ? 'Email' : 'Phone',
              ),
              validator: (value) {
                final input = value?.trim() ?? '';
                if (input.isEmpty) {
                  return model.method == AuthMethod.email
                      ? 'Email is required'
                      : 'Phone is required';
                }
                if (model.method == AuthMethod.email && !input.contains('@')) {
                  return 'Enter a valid email';
                }
                if (model.method == AuthMethod.phone && input.length < 8) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passwordController,
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
            const SizedBox(height: 18),
            AppCard(
              color: AppColors.accentSoft,
              child: Row(
                children: [
                  const Icon(Icons.verified_user, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      model.isLogin
                          ? 'Only verified admin accounts can access the dashboard.'
                          : 'New accounts must be verified as admin before access.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: model.isSubmitting ? null : onSubmit,
                child: model.isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(model.isLogin ? 'Login' : 'Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminFooterNote extends StatelessWidget {
  const _AdminFooterNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Need help? Contact the main admin to enable access for your account.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
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
      onSelectionChanged: (values) => onChanged(values.first),
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
          Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
