import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
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
  bool _showAllTracks = false;
  bool _showAllResources = false;

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
    final tracks = [
      const _TrackData(
        title: 'Flutter & Mobile',
        subtitle: 'Build real apps, UI, and APIs.',
        steps: ['Dart basics', 'Widgets & layouts', 'State management'],
      ),
      const _TrackData(
        title: 'Web Development',
        subtitle: 'Front-end + backend foundations.',
        steps: ['HTML/CSS/JS', 'REST APIs', 'Deployments'],
      ),
      const _TrackData(
        title: 'DSA & Problem Solving',
        subtitle: 'Crack logic with daily practice.',
        steps: ['Arrays & strings', 'Stacks/queues', 'Trees & graphs'],
      ),
      const _TrackData(
        title: 'DBMS & SQL',
        subtitle: 'Master queries and data modeling.',
        steps: ['ER modeling', 'SQL joins', 'Normalization'],
      ),
    ];
    final resources = [
      const _ResourceLink(
        title: 'freeCodeCamp',
        subtitle: 'Full free courses + certifications',
        url: 'https://www.freecodecamp.org',
      ),
      const _ResourceLink(
        title: 'The Odin Project',
        subtitle: 'Free full‑stack web curriculum',
        url: 'https://www.theodinproject.com',
      ),
      const _ResourceLink(
        title: 'Khan Academy',
        subtitle: 'Free CS & programming basics',
        url: 'https://www.khanacademy.org/computing',
      ),
      const _ResourceLink(
        title: 'MIT OpenCourseWare',
        subtitle: 'Free university courses',
        url: 'https://ocw.mit.edu',
      ),
      const _ResourceLink(
        title: 'CS50',
        subtitle: 'Harvard’s intro to CS (free)',
        url: 'https://cs50.harvard.edu/x/',
      ),
      const _ResourceLink(
        title: 'Exercism',
        subtitle: 'Free practice with mentorship',
        url: 'https://exercism.org',
      ),
      const _ResourceLink(
        title: 'MDN Web Docs',
        subtitle: 'Free web development reference',
        url: 'https://developer.mozilla.org',
      ),
      const _ResourceLink(
        title: 'NPTEL',
        subtitle: 'Free university courses (India)',
        url: 'https://nptel.ac.in',
      ),
    ];
    final visibleTracks =
        _showAllTracks ? tracks : tracks.take(1).toList();
    final visibleResources =
        _showAllResources ? resources : resources.take(3).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            context.l10n.programmingWorld,
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
              const SizedBox(height: 16),
              _SectionTitle(
                title: context.tr('Learning Tracks', 'अध्ययन ट्र्याकहरू'),
              ),
              const SizedBox(height: 12),
              ...visibleTracks
                  .map(
                    (track) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TrackCard(
                        title: track.title,
                        subtitle: track.subtitle,
                        steps: track.steps,
                      ),
                    ),
                  ),
              _SectionAction(
                label: _showAllTracks
                    ? context.tr('Show fewer tracks', 'कम ट्र्याक देखाउनुहोस्')
                    : context.tr('View all tracks', 'सबै ट्र्याक हेर्नुहोस्'),
                onTap: () {
                  setState(() => _showAllTracks = !_showAllTracks);
                },
              ),
              const SizedBox(height: 20),
              _SectionTitle(
                title: context.tr('Daily Practice', 'दैनिक अभ्यास'),
              ),
              const SizedBox(height: 12),
              _PracticeArenaCard(
                onLaunch: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CodeFixGameScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              _SectionTitle(
                title: context.tr('Free Resources', 'निःशुल्क स्रोतहरू'),
              ),
              const SizedBox(height: 12),
              ...visibleResources
                  .map(
                    (resource) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LinkCard(
                        title: resource.title,
                        subtitle: resource.subtitle,
                        url: resource.url,
                      ),
                    ),
                  ),
              _SectionAction(
                label: _showAllResources
                    ? context.tr(
                        'Show fewer resources',
                        'कम स्रोत देखाउनुहोस्',
                      )
                    : context.tr('View all resources', 'सबै स्रोत हेर्नुहोस्'),
                onTap: () {
                  setState(() => _showAllResources = !_showAllResources);
                },
              ),
              const SizedBox(height: 20),
              _SectionTitle(
                title: context.tr('Ideas & Tips', 'आइडिया र सुझाव'),
              ),
              const SizedBox(height: 12),
              const _CompactIdeasTipsCard(),
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
            context.tr(
              'Build skills that matter',
              'काम लाग्ने सिप विकास गर्नुहोस्',
            ),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Your personal programming hub with tracks, practice, and projects.',
              'ट्र्याक, अभ्यास र प्रोजेक्ट सहित तपाईंको व्यक्तिगत प्रोग्रामिङ हब।',
            ),
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

class _TrackData {
  final String title;
  final String subtitle;
  final List<String> steps;

  const _TrackData({
    required this.title,
    required this.subtitle,
    required this.steps,
  });
}

class _ResourceLink {
  final String title;
  final String subtitle;
  final String url;

  const _ResourceLink({
    required this.title,
    required this.subtitle,
    required this.url,
  });
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

class _SectionAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SectionAction({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          foregroundColor: const Color(0xFF4FA3C7),
          textStyle: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}

class _PracticeArenaCard extends StatelessWidget {
  final VoidCallback onLaunch;

  const _PracticeArenaCard({required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Today’s plan', 'आजको योजना'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 10),
          _Bullet(
            context.tr(
              'Solve 2 easy DSA problems',
              '२ सजिला DSA समस्या समाधान गर्नुहोस्',
            ),
          ),
          _Bullet(
            context.tr(
              'Revise DBMS joins + write 3 queries',
              'DBMS joins दोहोर्याउनुहोस् + ३ query लेख्नुहोस्',
            ),
          ),
          _Bullet(
            context.tr(
              'Build 1 small UI screen in Flutter',
              'Flutter मा १ सानो UI स्क्रिन बनाउनुहोस्',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _TagChip(label: context.tr('Timer', 'टाइमर')),
              const SizedBox(width: 6),
              _TagChip(label: context.tr('MCQ', 'MCQ')),
              const SizedBox(width: 6),
              _TagChip(label: context.tr('Streak Bonus', 'स्ट्रिक बोनस')),
            ],
          ),
          const SizedBox(height: 12),
          _PrimaryActionButton(
            label: context.tr('Enter Code Fix Arena', 'कोड फिक्स एरिनामा जानुहोस्'),
            enabled: true,
            onPressed: onLaunch,
          ),
        ],
      ),
    );
  }
}

class _CompactIdeasTipsCard extends StatelessWidget {
  const _CompactIdeasTipsCard();

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Mini projects', 'मिनी प्रोजेक्टहरू'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          _Bullet(
            context.tr('Notes organizer with search', 'खोज सहित नोट्स आयोजक'),
          ),
          _Bullet(
            context.tr('Quiz app with timer and score', 'टाइमर र स्कोर सहित क्विज एप'),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('Pro tips', 'प्रो सुझावहरू'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          _Bullet(
            context.tr(
              'Practice daily for 30–45 minutes.',
              'दैनिक ३०–४५ मिनेट अभ्यास गर्नुहोस्।',
            ),
          ),
          _Bullet(
            context.tr(
              'Build small projects every week.',
              'हरेक हप्ता सानो प्रोजेक्ट बनाउनुहोस्।',
            ),
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
                      color: Color(0xFF4FA3C7)),
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
                      const SizedBox(height: 6),
                      Text(
                        context.tr(
                          'Source: ${_hostLabel(url)}. Opens original site.',
                          'स्रोत: ${_hostLabel(url)}। मौलिक साइट खोलिन्छ।',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white60),
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

String _hostLabel(String url) {
  final host = Uri.tryParse(url)?.host ?? url;
  return host.startsWith('www.') ? host.substring(4) : host;
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
      ..color = const Color(0xFF4FA3C7).withValues(alpha: 0.10)
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
            Color(0xFF4FA3C7),
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
              Color(0xFF4FA3C7),
              Color(0xFF4F46E5),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4FA3C7).withValues(alpha: 0.35),
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
