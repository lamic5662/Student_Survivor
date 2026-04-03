import 'package:flutter/material.dart';
import 'package:student_survivor/features/games/code_fix_game_screen.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';

class ProgrammingWorldScreen extends StatefulWidget {
  const ProgrammingWorldScreen({super.key});

  @override
  State<ProgrammingWorldScreen> createState() => _ProgrammingWorldScreenState();
}

class _ProgrammingWorldScreenState extends State<ProgrammingWorldScreen> {
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
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            'Programming World',
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
          const Positioned.fill(child: _ProgrammingBackdrop()),
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + kToolbarHeight + 12,
              20,
              28,
            ),
            children: [
              _HeroCard(),
              const SizedBox(height: 20),
              const _SectionTitle(title: 'Learning Tracks'),
              const SizedBox(height: 12),
              const _TrackCard(
                title: 'Flutter & Mobile',
                subtitle: 'Build real apps, UI, and APIs.',
                steps: ['Dart basics', 'Widgets & layouts', 'State management'],
              ),
              const SizedBox(height: 12),
              const _TrackCard(
                title: 'Web Development',
                subtitle: 'Front-end + backend foundations.',
                steps: ['HTML/CSS/JS', 'REST APIs', 'Deployments'],
              ),
              const SizedBox(height: 12),
              const _TrackCard(
                title: 'DSA & Problem Solving',
                subtitle: 'Crack logic with daily practice.',
                steps: ['Arrays & strings', 'Stacks/queues', 'Trees & graphs'],
              ),
              const SizedBox(height: 12),
              const _TrackCard(
                title: 'DBMS & SQL',
                subtitle: 'Master queries and data modeling.',
                steps: ['ER modeling', 'SQL joins', 'Normalization'],
              ),
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Daily Practice'),
              const SizedBox(height: 12),
              const _PracticeCard(),
              const SizedBox(height: 16),
              _CodeArenaCard(
                onLaunch: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CodeFixGameScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Project Ideas'),
              const SizedBox(height: 12),
              const _ProjectIdeas(),
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Free Resources'),
              const SizedBox(height: 12),
              _LinkCard(
                title: 'freeCodeCamp',
                subtitle: 'Full free courses + certifications',
                url: 'https://www.freecodecamp.org',
              ),
              const SizedBox(height: 12),
              _LinkCard(
                title: 'The Odin Project',
                subtitle: 'Free full‑stack web curriculum',
                url: 'https://www.theodinproject.com',
              ),
              const SizedBox(height: 12),
              _LinkCard(
                title: 'Khan Academy',
                subtitle: 'Free CS & programming basics',
                url: 'https://www.khanacademy.org/computing',
              ),
              const SizedBox(height: 12),
              _LinkCard(
                title: 'MIT OpenCourseWare',
                subtitle: 'Free university courses',
                url: 'https://ocw.mit.edu',
              ),
              const SizedBox(height: 12),
              _LinkCard(
                title: 'CS50',
                subtitle: 'Harvard’s intro to CS (free)',
                url: 'https://cs50.harvard.edu/x/',
              ),
              const SizedBox(height: 12),
              _LinkCard(
                title: 'Exercism',
                subtitle: 'Free practice with mentorship',
                url: 'https://exercism.org',
              ),
              const SizedBox(height: 12),
              _LinkCard(
                title: 'MDN Web Docs',
                subtitle: 'Free web development reference',
                url: 'https://developer.mozilla.org',
              ),
              const SizedBox(height: 12),
              _LinkCard(
                title: 'NPTEL',
                subtitle: 'Free university courses (India)',
                url: 'https://nptel.ac.in',
              ),
              const SizedBox(height: 24),
              const _SectionTitle(title: 'Pro Tips'),
              const SizedBox(height: 12),
              const _TipsCard(),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _GameCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Build skills that matter',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your personal programming hub with tracks, practice, and projects.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> steps;

  const _TrackCard({
    required this.title,
    required this.subtitle,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 10),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: Color(0xFF22C55E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard();

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today’s plan',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 10),
          const _Bullet('Solve 2 easy DSA problems'),
          const _Bullet('Revise DBMS joins + write 3 queries'),
          const _Bullet('Build 1 small UI screen in Flutter'),
        ],
      ),
    );
  }
}

class _ProjectIdeas extends StatelessWidget {
  const _ProjectIdeas();

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mini projects you can build',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 10),
          const _Bullet('Notes organizer with search'),
          const _Bullet('Quiz app with timer and score'),
          const _Bullet('Habit tracker with streaks'),
          const _Bullet('Expense tracker with charts'),
        ],
      ),
    );
  }
}

class _CodeArenaCard extends StatelessWidget {
  final VoidCallback onLaunch;

  const _CodeArenaCard({required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF111B2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2A44)),
                ),
                child:
                    const Icon(Icons.code, color: Color(0xFF38BDF8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Code Fix Arena',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Find errors, fix code, and earn streak points.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TagChip(label: 'Timer'),
              const SizedBox(width: 6),
              _TagChip(label: 'MCQ'),
              const SizedBox(width: 6),
              _TagChip(label: 'Streak Bonus'),
            ],
          ),
          const SizedBox(height: 14),
          _PrimaryActionButton(
            label: 'Enter Arena',
            enabled: true,
            onPressed: onLaunch,
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String url;

  const _LinkCard({
    required this.title,
    required this.subtitle,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SyllabusWebViewScreen(
                  title: title,
                  url: url,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111B2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E2A44)),
                  ),
                  child: const Icon(Icons.open_in_new_rounded,
                      color: Color(0xFF38BDF8)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
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
          ),
        ),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _Bullet('Practice daily for 30–45 minutes.'),
          _Bullet('Build small projects every week.'),
          _Bullet('Review weak topics every weekend.'),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(color: Colors.white70)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _ProgrammingBackdrop extends StatelessWidget {
  const _ProgrammingBackdrop();

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
          Positioned.fill(child: CustomPaint(painter: _ProgrammingGridPainter())),
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

class _ProgrammingGridPainter extends CustomPainter {
  const _ProgrammingGridPainter();

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
  bool shouldRepaint(covariant _ProgrammingGridPainter oldDelegate) => false;
}

class _GameCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const _GameCard({required this.child, this.padding});

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
        padding: padding ?? const EdgeInsets.all(16),
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

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.enabled,
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
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style:
                const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}
