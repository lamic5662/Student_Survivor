import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';
import 'package:student_survivor/features/subjects/subject_detail_screen.dart';
import 'package:student_survivor/features/subjects/subjects_presenter.dart';
import 'package:student_survivor/features/subjects/subjects_view_model.dart';
import 'package:student_survivor/models/app_models.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState
    extends PresenterState<SubjectsScreen, SubjectsView, SubjectsPresenter>
    implements SubjectsView {
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
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

  @override
  SubjectsPresenter createPresenter() => SubjectsPresenter();

  void _openSyllabus(BuildContext context, Subject subject) {
    final url = subject.syllabusUrl?.trim() ?? '';
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No syllabus available yet.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SyllabusWebViewScreen(
          title: '${subject.name} syllabus',
          url: url,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SubjectsViewModel>(
      valueListenable: presenter.state,
      builder: (context, model, _) {
        final subjects = model.subjects;
        Subject? syllabusSubject;
        for (final subject in subjects) {
          if ((subject.syllabusUrl ?? '').trim().isNotEmpty) {
            syllabusSubject = subject;
            break;
          }
        }
        final totalChapters =
            subjects.fold<int>(0, (sum, subject) => sum + subject.chapters.length);
        final totalQuizzes = subjects.fold<int>(
          0,
          (sum, subject) =>
              sum +
              subject.chapters.fold<int>(
                0,
                (count, chapter) => count + chapter.quizzes.length,
              ),
        );
        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: const Color(0xFF070B14),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: AnimatedOpacity(
              opacity: _showTitle ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subjects',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    model.semesterName,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          body: Stack(
            children: [
              const Positioned.fill(child: _SubjectsBackdrop()),
              ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  kToolbarHeight + 48,
                  20,
                  28,
                ),
                children: [
                  _GameCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1220),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF1E2A44)),
                          ),
                          child: const Icon(Icons.menu_book_rounded,
                              color: Color(0xFF38BDF8)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Subjects',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Pick a subject to explore notes and quizzes.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoChip(
                                      label: '${subjects.length} subjects'),
                                  _InfoChip(
                                      label: '$totalChapters chapters'),
                                  _InfoChip(label: '$totalQuizzes quizzes'),
                                ],
                              ),
                              if (syllabusSubject != null) ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: _ActionButton(
                                    label: 'Open syllabus',
                                    icon: Icons.description_rounded,
                                    onPressed: () => _openSyllabus(
                                      context,
                                      syllabusSubject!,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (subjects.isEmpty)
                    _GameCard(
                      child: Column(
                        children: [
                          const Icon(Icons.menu_book_outlined,
                              size: 48, color: Colors.white70),
                          const SizedBox(height: 12),
                          Text(
                            'No subjects available.',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Select a semester to load subjects.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  else
                    ...subjects.asMap().entries.map((entry) {
                      final subject = entry.value;
                      final quizzes = subject.chapters.fold<int>(
                        0,
                        (sum, chapter) => sum + chapter.quizzes.length,
                      );
                      final progress =
                          (0.4 + entry.key * 0.08).clamp(0.1, 1.0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _SubjectCard(
                          subject: subject,
                          quizzes: quizzes,
                          progress: progress,
                          onOpen: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SubjectDetailScreen(subject: subject),
                              ),
                            );
                          },
                        ),
                      );
                    }),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final int quizzes;
  final double progress;
  final VoidCallback onOpen;

  const _SubjectCard({
    required this.subject,
    required this.quizzes,
    required this.progress,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1220),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E2A44)),
                  ),
                  child: Icon(Icons.menu_book_rounded,
                      color: subject.accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                      ),
                      Text(
                        subject.code,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white54),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(label: '${subject.chapters.length} chapters'),
                _InfoChip(label: '$quizzes quizzes'),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF1E2A44),
                color: subject.accentColor,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            _ActionButton(
              label: 'Open Subject',
              icon: Icons.play_arrow_rounded,
              onPressed: onOpen,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SubjectsBackdrop extends StatelessWidget {
  const _SubjectsBackdrop();

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
          Positioned.fill(child: CustomPaint(painter: _SubjectsGridPainter())),
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

class _SubjectsGridPainter extends CustomPainter {
  const _SubjectsGridPainter();

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
  bool shouldRepaint(covariant _SubjectsGridPainter oldDelegate) => false;
}

class _GameCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GameCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

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
        padding: padding,
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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF38BDF8),
              Color(0xFF4F46E5),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(icon, size: 18),
          label: Text(
            label.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}
