import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';

class GameZoneScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? overlay;
  final bool useSafeArea;

  const GameZoneScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.overlay,
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: appBar,
      body: Stack(
        children: [
          const _GameZoneBackground(),
          if (useSafeArea) SafeArea(child: body) else body,
          // ignore: use_null_aware_elements
          if (overlay != null) overlay!,
        ],
      ),
    );
  }
}

class _GameZoneBackground extends StatelessWidget {
  const _GameZoneBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.12),
                    AppColors.accent.withValues(alpha: 0.08),
                    AppColors.paper,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
          const Positioned(
            top: -90,
            right: -70,
            child: _GlowCircle(
              size: 220,
              color: Color(0x336366F1),
            ),
          ),
          const Positioned(
            bottom: -120,
            left: -80,
            child: _GlowCircle(
              size: 240,
              color: Color(0x3314B8A6),
            ),
          ),
          const Positioned(
            top: 120,
            left: -60,
            child: _GlowCircle(
              size: 140,
              color: Color(0x224F46E5),
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
      ),
    );
  }
}
