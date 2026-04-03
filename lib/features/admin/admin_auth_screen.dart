import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
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
  AuthPresenter createPresenter() => AuthPresenter(
        signupMetadata: const {
          'admin_signup': true,
        },
      );

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
                  Color(0xFF071526),
                  Color(0xFF0F2E3F),
                  Color(0xFF0B3558),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                const _AdminBackdrop(),
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

class _AdminBackdrop extends StatelessWidget {
  const _AdminBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        Positioned.fill(child: CustomPaint(painter: _AdminPatternPainter())),
        Positioned(
          top: -80,
          right: -50,
          child: _GlowOrb(
            size: 220,
            color: Color(0x3344C3FF),
          ),
        ),
        Positioned(
          bottom: -70,
          left: -40,
          child: _GlowOrb(
            size: 200,
            color: Color(0x33F97316),
          ),
        ),
        Positioned(
          top: 140,
          left: 24,
          child: _GlowOrb(
            size: 140,
            color: Color(0x3322D3EE),
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

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
            blurRadius: 70,
            spreadRadius: 12,
          ),
        ],
      ),
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
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.76),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _GradientTitle(text: 'Admin Studio'),
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
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
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
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
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
        gradient: isActive
            ? const LinearGradient(
                colors: [
                  Color(0xFF38BDF8),
                  Color(0xFF6366F1),
                ],
              )
            : null,
        color: isActive ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
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
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.7),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.92),
                const Color(0xFFF1F5F9).withValues(alpha: 0.88),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
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
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          model.isLogin
                              ? 'Only admin accounts can access the dashboard.'
                              : 'New accounts are granted admin access automatically.',
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
            color: Colors.white.withValues(alpha: 0.75),
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
            return const Color(0xFF38BDF8).withValues(alpha: 0.18);
          }
          return Colors.white.withValues(alpha: 0.6);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF0F172A);
          }
          return const Color(0xFF0F172A).withValues(alpha: 0.7);
        }),
        side: WidgetStateProperty.resolveWith(
          (_) => BorderSide(color: Colors.white.withValues(alpha: 0.6)),
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

class _GradientTitle extends StatelessWidget {
  final String text;

  const _GradientTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: Colors.white,
        );
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [
          Color(0xFF38BDF8),
          Color(0xFF22D3EE),
          Color(0xFF6366F1),
        ],
      ).createShader(rect),
      child: Text(text, style: style),
    );
  }
}

class _AdminPatternPainter extends CustomPainter {
  static final List<Offset> _dots = List.generate(
    24,
    (index) => Offset(
      (0.06 + (index * 0.23)) % 1.0,
      (0.14 + (index * 0.31)) % 1.0,
    ),
  );

  const _AdminPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (int i = 0; i < 5; i += 1) {
      final y = size.height * (0.2 + i * 0.14);
      canvas.drawLine(
        Offset(-20, y),
        Offset(size.width + 20, y - 50),
        linePaint,
      );
    }

    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..moveTo(0, size.height * 0.74)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.62,
        size.width * 0.72,
        size.height * 0.7,
      )
      ..quadraticBezierTo(
        size.width * 0.92,
        size.height * 0.78,
        size.width,
        size.height * 0.7,
      );
    canvas.drawPath(path, wavePaint);

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22);
    for (final point in _dots) {
      canvas.drawCircle(
        Offset(size.width * point.dx, size.height * point.dy),
        2,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AdminPatternPainter oldDelegate) => false;
}
