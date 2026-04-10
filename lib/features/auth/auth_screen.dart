import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
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
    with SingleTickerProviderStateMixin
    implements AuthView {
  static const _lastEmailKey = 'auth_last_email';
  static const _lastPhoneKey = 'auth_last_phone';
  static const _aiDisclaimerKey = 'ai_disclaimer_pending';
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  AnimationController? _scanline;

  @override
  AuthPresenter createPresenter() => AuthPresenter();

  @override
  void initState() {
    super.initState();
    _scanline = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _loadSavedIdentifier(AuthMethod.email);
  }

  @override
  void dispose() {
    _scanline?.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void goToHome() {
    () async {
      final save = await _promptSaveLoginIfNeeded();
      TextInput.finishAutofillContext(shouldSave: save);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_aiDisclaimerKey, true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    }();
  }

  Future<void> _loadSavedIdentifier(
    AuthMethod method, {
    bool force = false,
  }) async {
    if (!force && _identifierController.text.trim().isNotEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final key = method == AuthMethod.email ? _lastEmailKey : _lastPhoneKey;
    final saved = prefs.getString(key);
    if (saved == null || saved.trim().isEmpty) return;
    if (!mounted) return;
    setState(() {
      _identifierController.text = saved;
    });
  }

  Future<void> _storeLastIdentifier(AuthMethod method, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final key = method == AuthMethod.email ? _lastEmailKey : _lastPhoneKey;
    await prefs.setString(key, trimmed);
  }

  Future<bool> _promptSaveLoginIfNeeded() async {
    final method = presenter.state.value.method;
    final prefs = await SharedPreferences.getInstance();
    final key = method == AuthMethod.email ? _lastEmailKey : _lastPhoneKey;
    final existing = prefs.getString(key);
    if (existing != null && existing.trim().isNotEmpty) {
      return true;
    }

    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B1220),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E2A44)),
          ),
          title: Text(
            context.tr('Save login?', 'लगइन सेभ गर्ने?'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          content: Text(
            context.tr(
              'Save your email/phone for quick login. Your device may also offer to save the password.',
              'छिटो लगइनका लागि इमेल/फोन सेभ गर्नुहोस्। तपाईंको डिभाइसले पासवर्ड पनि सेभ गर्न प्रस्ताव गर्न सक्छ।',
            ),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                context.tr('Not now', 'अहिल्यै होइन'),
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4FA3C7),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.tr('Save', 'सेभ')),
            ),
          ],
        );
      },
    );

    final save = result == true;
    if (save) {
      await _storeLastIdentifier(method, _identifierController.text);
    }
    return save;
  }

  void _handleAuthMethodChanged(AuthMethod method) {
    presenter.setAuthMethod(method);
    _loadSavedIdentifier(method, force: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: ValueListenableBuilder<AuthViewModel>(
          valueListenable: presenter.state,
          builder: (context, model, _) {
            final theme = Theme.of(context);
            final l10n = context.l10n;
            InputDecoration gameInputDecoration({
              required String label,
              required IconData icon,
            }) {
              return InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(color: Color(0xFFB6C2D9)),
                floatingLabelStyle: const TextStyle(color: Color(0xFF7DD3FC)),
                prefixIcon: Icon(icon, color: const Color(0xFF9FB3C8)),
                filled: true,
                fillColor: const Color(0xFF0B1220),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF1E2A44)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF4FA3C7),
                    width: 1.4,
                  ),
                ),
              );
            }
            return Stack(
              children: [
                const _AuthBackdrop(),
                Positioned.fill(
                  child: IgnorePointer(
                    child: _ScanlineOverlay(
                      animation: _scanline ??=
                          AnimationController(
                            vsync: this,
                            duration: const Duration(milliseconds: 2200),
                          )..repeat(),
                    ),
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 860;
                      const hero = _AuthHero();
                      final card = _AuthCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    l10n.accessPortal.toUpperCase(),
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.6),
                                      letterSpacing: 1.4,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  _StatusChip(
                                    label: model.isLogin
                                        ? l10n.login.toUpperCase()
                                        : l10n.signup.toUpperCase(),
                                    glow: model.isLogin
                                        ? const Color(0xFF4FA3C7)
                                        : const Color(0xFFA78BFA),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 1,
                                width: double.infinity,
                                color: const Color(0xFF1E2A44),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: _ModeToggle(
                                  isLogin: model.isLogin,
                                  onToggle: presenter.toggleMode,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                model.isLogin
                                    ? l10n.welcomeBack
                                    : l10n.createAccount,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                model.isLogin
                                    ? l10n.loginSubtitle
                                    : l10n.signupSubtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _AuthMethodSelector(
                                selected: model.method,
                                onChanged: _handleAuthMethodChanged,
                              ),
                              const SizedBox(height: 16),
                              AutofillGroup(
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _identifierController,
                                      keyboardType:
                                          model.method == AuthMethod.email
                                              ? TextInputType.emailAddress
                                              : TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      autofillHints:
                                          model.method == AuthMethod.email
                                              ? const [
                                                  AutofillHints.email,
                                                  AutofillHints.username,
                                                ]
                                              : const [
                                                  AutofillHints.telephoneNumber,
                                                ],
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: gameInputDecoration(
                                        label: model.method == AuthMethod.email
                                            ? l10n.email
                                            : l10n.phone,
                                        icon: model.method == AuthMethod.email
                                            ? Icons.alternate_email
                                            : Icons.phone_iphone,
                                      ),
                                      validator: (value) {
                                        final input = value?.trim() ?? '';
                                        if (input.isEmpty) {
                                          return model.method ==
                                                  AuthMethod.email
                                              ? l10n.emailRequired
                                              : l10n.phoneRequired;
                                        }
                                        if (model.method ==
                                                AuthMethod.email &&
                                            !input.contains('@')) {
                                          return l10n.validEmail;
                                        }
                                        if (model.method == AuthMethod.phone &&
                                            input.length < 8) {
                                          return l10n.validPhone;
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: true,
                                      textInputAction: TextInputAction.done,
                                      autofillHints: const [
                                        AutofillHints.password,
                                      ],
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: gameInputDecoration(
                                        label: l10n.password,
                                        icon: Icons.lock_outline,
                                      ),
                                      validator: (value) {
                                        final input = value?.trim() ?? '';
                                        if (input.isEmpty) {
                                          return l10n.passwordRequired;
                                        }
                                        if (input.length < 6) {
                                          return l10n.passwordMin;
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              const _InfoCallout(),
                              const SizedBox(height: 22),
                              _AuthPrimaryButton(
                                isLoading: model.isSubmitting,
                                label: model.isLogin
                                    ? l10n.continueAction
                                    : l10n.createAccountAction,
                                onPressed: model.isSubmitting
                                    ? null
                                    : () {
                                        if (_formKey.currentState?.validate() !=
                                            true) {
                                          return;
                                        }
                                        presenter.submit(
                                          identifier: _identifierController.text
                                              .trim(),
                                          password: _passwordController.text,
                                        );
                                      },
                              ),
                            ],
                          ),
                        ),
                      );
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 60,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              isWide
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 5, child: hero),
                                        const SizedBox(width: 30),
                                        Expanded(flex: 4, child: card),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        hero,
                                        const SizedBox(height: 22),
                                        card,
                                      ],
                                    ),
                              const SizedBox(height: 18),
                              const _AuthFooterNote(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
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
            Color(0xFF070B14),
            Color(0xFF0B1324),
            Color(0xFF101C2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: const [
          Positioned.fill(child: CustomPaint(painter: _GameGridPainter())),
          Positioned(
            top: -120,
            right: -60,
            child: _GlowSpot(
              size: 260,
              color: Color(0x3322D3EE),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -40,
            child: _GlowSpot(
              size: 220,
              color: Color(0x334F46E5),
            ),
          ),
          Positioned(
            top: 140,
            left: 40,
            child: _GlowSpot(
              size: 160,
              color: Color(0x332DD4BF),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowSpot extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowSpot({required this.size, required this.color});

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
            spreadRadius: 14,
          ),
        ],
      ),
    );
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1220),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              const _GradientTitle(text: 'StudentSurge'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Enter the arena. Learn fast. Level up.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _FeatureTag(icon: Icons.shield, label: 'Survivor Mode'),
              _FeatureTag(icon: Icons.psychology, label: 'AI Coach'),
            ],
          ),
        ],
      ),
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
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1E2A44)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4FA3C7).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4FA3C7)),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
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

  const _ModeToggle({
    required this.isLogin,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E2A44)),
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [
                      Color(0xFF4FA3C7),
                      Color(0xFF6366F1),
                    ],
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF4FA3C7).withValues(alpha: 0.35),
                      blurRadius: 16,
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
                color:
                    selected ? Colors.white : Colors.white.withValues(alpha: 0.7),
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
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF22D3EE),
            Color(0xFF4FA3C7),
            Color(0xFF4F46E5),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0xFF1E2A44)),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0x3322D3EE),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
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
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E2A44),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 22, color: Color(0xFF4FA3C7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Complete your semester + subjects in Profile after login.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
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
            return const Color(0xFF1E293B);
          }
          return const Color(0xFF0B1220);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF4FA3C7);
          }
          return Colors.white.withValues(alpha: 0.7);
        }),
        side: WidgetStateProperty.resolveWith(
          (_) => const BorderSide(color: Color(0xFF1E2A44)),
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

class _AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _AuthPrimaryButton({
    required this.label,
    required this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF007AFF),
              Color(0xFF4F46E5),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4FA3C7).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color glow;

  const _StatusChip({
    required this.label,
    required this.glow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1E2A44)),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: glow,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
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
          Color(0xFF4FA3C7),
          Color(0xFF22D3EE),
          Color(0xFFA78BFA),
        ],
      ).createShader(rect),
      child: Text(text, style: style),
    );
  }
}

class _GameGridPainter extends CustomPainter {
  const _GameGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.4)
      ..strokeWidth = 1;
    const gap = 44.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final glowPaint = Paint()
      ..color = const Color(0xFF4FA3C7).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = Rect.fromLTWH(
      size.width * 0.1,
      size.height * 0.12,
      size.width * 0.8,
      size.height * 0.7,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GameGridPainter oldDelegate) => false;
}

class _ScanlineOverlay extends StatelessWidget {
  final Animation<double> animation;

  const _ScanlineOverlay({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          painter: _ScanlinePainter(progress: animation.value),
        );
      },
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  final double progress;

  const _ScanlinePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final scanPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    const gap = 14.0;
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanPaint);
    }

    final bandY = (size.height + 120) * progress - 60;
    final bandPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF4FA3C7).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, bandY, size.width, 120));
    canvas.drawRect(Rect.fromLTWH(0, bandY, size.width, 120), bandPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _AuthFooterNote extends StatelessWidget {
  const _AuthFooterNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      '© 2026 StudentSurge. All rights reserved.',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.65),
          ),
    );
  }
}
