import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GameZoneScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? overlay;
  final bool useSafeArea;
  final bool extendBodyBehindAppBar;

  const GameZoneScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.overlay,
    this.useSafeArea = true,
    this.extendBodyBehindAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF070B14),
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        extendBody: extendBodyBehindAppBar,
        appBar: appBar,
        body: Stack(
          children: [
            const _GameZoneBackground(),
            if (useSafeArea) SafeArea(child: body) else body,
            // ignore: use_null_aware_elements
            if (overlay != null) overlay!,
          ],
        ),
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
                    Color(0xFF070B14),
                    Color(0xFF0B1324),
                    Color(0xFF101C2E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          const Positioned.fill(child: CustomPaint(painter: _GameZoneGrid())),
          const Positioned(
            top: -140,
            right: -80,
            child: _GlowCircle(
              size: 280,
              color: Color(0x3322D3EE),
            ),
          ),
          const Positioned(
            bottom: -120,
            left: -60,
            child: _GlowCircle(
              size: 240,
              color: Color(0x334F46E5),
            ),
          ),
          const Positioned(
            top: 160,
            left: 40,
            child: _GlowCircle(
              size: 180,
              color: Color(0x332DD4BF),
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
            blurRadius: 80,
            spreadRadius: 16,
          ),
        ],
      ),
    );
  }
}

class _GameZoneGrid extends CustomPainter {
  const _GameZoneGrid();

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.4)
      ..strokeWidth = 1;
    const gap = 52.0;
    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final glowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = Rect.fromLTWH(
      size.width * 0.08,
      size.height * 0.08,
      size.width * 0.84,
      size.height * 0.76,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(28)),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GameZoneGrid oldDelegate) => false;
}
