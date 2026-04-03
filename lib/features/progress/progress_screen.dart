import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/progress_service.dart';
import 'package:student_survivor/data/supabase_config.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final ProgressService _progressService;
  bool _isLoading = true;
  String? _errorMessage;
  double _overall = 0;
  ProgressSnapshot? _snapshot;
  Map<String, double> _subjectProgress = const {};
  late final VoidCallback _listener;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;

  @override
  void initState() {
    super.initState();
    _progressService = ProgressService(SupabaseConfig.client);
    _listener = _load;
    AppState.profile.addListener(_listener);
    _load();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    AppState.profile.removeListener(_listener);
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset < 24;
    if (shouldShow != _showTitle) {
      setState(() => _showTitle = shouldShow);
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final subjects = AppState.profile.value.subjects;
      final snapshot =
          await _progressService.fetchProgressSnapshot(subjects);
      final subjectProgress =
          await _progressService.fetchSubjectProgress(subjects);
      if (!mounted) return;
      setState(() {
        _overall = snapshot.overall;
        _snapshot = snapshot;
        _subjectProgress = subjectProgress;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load progress: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppState.profile.value;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            'Progress Tracking',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _ProgressBackdrop()),
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + kToolbarHeight + 12,
              20,
              28,
            ),
            children: [
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF38BDF8),
                  ),
                )
              else if (_errorMessage != null)
                _GameCard(
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Color(0xFFF87171)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style:
                              const TextStyle(color: Color(0xFFF87171)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _GameCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall learning progress',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _overall,
                        backgroundColor: const Color(0xFF1E2A44),
                        color: const Color(0xFF38BDF8),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_overall * 100).round()}% overall progress',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              if (_snapshot != null) ...[
                const SizedBox(height: 16),
                _GameCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Feature progress',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 12),
                      _FeatureProgressRow(
                        label: 'Syllabus',
                        value: _snapshot!.syllabus,
                        color: AppColors.secondary,
                      ),
                      _FeatureProgressRow(
                        label: 'Planner',
                        value: _snapshot!.planner,
                        color: AppColors.accent,
                      ),
                      _FeatureProgressRow(
                        label: 'Practice',
                        value: _snapshot!.practice,
                        color: AppColors.success,
                      ),
                      _FeatureProgressRow(
                        label: 'AI Usage',
                        value: _snapshot!.ai,
                        color: AppColors.warning,
                      ),
                      _FeatureProgressRow(
                        label: 'Community',
                        value: _snapshot!.community,
                        color: AppColors.danger,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(
                'Subject progress',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              if (profile.subjects.isEmpty)
                const Text(
                  'Select a semester to track progress.',
                  style: TextStyle(color: Colors.white70),
                )
              else
                ...profile.subjects.map(
                  (subject) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GameCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _subjectProgress[subject.id] ?? 0,
                            backgroundColor: const Color(0xFF1E2A44),
                            color: subject.accentColor,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureProgressRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _FeatureProgressRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).clamp(0, 100).toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
              ),
              Text(
                '$percent%',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: value,
            backgroundColor: const Color(0xFF1E2A44),
            color: color,
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}

class _ProgressBackdrop extends StatelessWidget {
  const _ProgressBackdrop();

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
          Positioned.fill(child: CustomPaint(painter: _ProgressGridPainter())),
          Positioned(
            top: -140,
            right: -80,
            child: _GlowOrb(size: 280, color: Color(0x3322D3EE)),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: _GlowOrb(size: 240, color: Color(0x334F46E5)),
          ),
          Positioned(
            top: 160,
            left: 40,
            child: _GlowOrb(size: 180, color: Color(0x332DD4BF)),
          ),
        ],
      ),
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
            blurRadius: 80,
            spreadRadius: 16,
          ),
        ],
      ),
    );
  }
}

class _ProgressGridPainter extends CustomPainter {
  const _ProgressGridPainter();

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
  bool shouldRepaint(covariant _ProgressGridPainter oldDelegate) => false;
}

class _GameCard extends StatelessWidget {
  final Widget child;

  const _GameCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF22D3EE),
            Color(0xFF38BDF8),
            Color(0xFF4F46E5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1E2A44)),
        ),
        child: child,
      ),
    );
  }
}
