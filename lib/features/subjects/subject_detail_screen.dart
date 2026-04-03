import 'package:flutter/material.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/data/user_notes_service.dart';
import 'package:student_survivor/features/games/battle_quiz_screen.dart';
import 'package:student_survivor/features/games/flashcards_screen.dart';
import 'package:student_survivor/features/games/subject_flashcards_screen.dart';
import 'package:student_survivor/features/games/survival_quiz_game_screen.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';
import 'package:student_survivor/features/subjects/chapter_detail_screen.dart';
import 'package:student_survivor/features/subjects/subject_study_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class SubjectDetailScreen extends StatefulWidget {
  final Subject subject;
  final bool useGameZoneTheme;

  const SubjectDetailScreen({
    super.key,
    required this.subject,
    this.useGameZoneTheme = false,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  late final UserNotesService _userNotesService;
  Map<String, int> _userNoteCounts = const {};
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;

  @override
  void initState() {
    super.initState();
    _userNotesService = UserNotesService(SupabaseConfig.client);
    _loadUserNotes();
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

  Future<void> _loadUserNotes() async {
    final chapterIds = widget.subject.chapters.map((c) => c.id).toList();
    if (chapterIds.isEmpty) {
      setState(() {
        _userNoteCounts = const {};
      });
      return;
    }
    try {
      final notes = await _userNotesService.fetchForSubject(chapterIds);
      if (!mounted) return;
      final counts = <String, int>{};
      for (final note in notes) {
        final chapterId = note.chapterId;
        if (chapterId == null || chapterId.isEmpty) {
          continue;
        }
        counts[chapterId] = (counts[chapterId] ?? 0) + 1;
      }
      setState(() {
        _userNoteCounts = counts;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userNoteCounts = const {};
      });
    }
  }

  int _totalNotesFor(Chapter chapter) {
    final userNotes = _userNoteCounts[chapter.id] ?? 0;
    return chapter.notes.length + userNotes;
  }

  Chapter _buildSubjectChapter() {
    final notes = <Note>[];
    final important = <Question>[];
    final past = <Question>[];
    final subtopics = <ChapterTopic>[];
    final seenTopics = <String>{};
    for (final chapter in widget.subject.chapters) {
      notes.addAll(chapter.notes);
      important.addAll(chapter.importantQuestions);
      past.addAll(chapter.pastQuestions);
      for (final topic in chapter.subtopics) {
        final title = topic.title.trim();
        if (title.isEmpty) continue;
        final key = title.toLowerCase();
        if (seenTopics.contains(key)) continue;
        seenTopics.add(key);
        subtopics.add(topic);
      }
    }
    return Chapter(
      id: 'subject_${widget.subject.id}',
      title: '${widget.subject.name} (All Chapters)',
      notes: notes,
      importantQuestions: important,
      pastQuestions: past,
      quizzes: const [],
      subtopics: subtopics,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useGameZoneTheme) {
      final appBar = AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.subject.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      );
      return GameZoneScaffold(
        appBar: appBar,
        body: _buildGameZoneBody(context),
        extendBodyBehindAppBar: true,
        useSafeArea: false,
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            widget.subject.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _SubjectBackdrop()),
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              kToolbarHeight + 36,
              20,
              28,
            ),
            children: [
              _GameCard(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1220),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF1E2A44)),
                      ),
                      child: Icon(Icons.menu_book,
                          color: widget.subject.accentColor),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject.code,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                        Text(
                          '${widget.subject.chapters.length} chapters',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (widget.subject.pastPapers.isNotEmpty) ...[
                _GameCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Past Question Papers',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      ...widget.subject.pastPapers.map(
                        (paper) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  paper.year == null
                                      ? paper.title
                                      : '${paper.title} (${paper.year})',
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.white70),
                                ),
                              ),
                              _inlineButton(
                                label: 'Open',
                                onPressed: () => _openSyllabus(
                                  context,
                                  paper.title,
                                  paper.fileUrl,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _GameCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study the Whole Subject',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generate AI notes, subject-level questions, and flashcards.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    _actionButton(
                      label: 'Open Subject Study',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SubjectStudyScreen(
                              subject: widget.subject,
                              useGameZoneTheme: widget.useGameZoneTheme,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...widget.subject.chapters.map(
                (chapter) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _GameCard(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context)
                            .push(
                          MaterialPageRoute(
                            builder: (_) => ChapterDetailScreen(
                              subject: widget.subject,
                              chapter: chapter,
                              useGameZoneTheme: widget.useGameZoneTheme,
                            ),
                          ),
                        )
                            .then((_) => _loadUserNotes());
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chapter.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_totalNotesFor(chapter)} notes, '
                            '${chapter.importantQuestions.length} important questions, '
                            '${chapter.quizzes.length} quizzes',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: 0.35,
                              backgroundColor: const Color(0xFF1E2A44),
                              color: widget.subject.accentColor,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildGameZoneBody(BuildContext context) {
    final subjectChapter = _buildSubjectChapter();
    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + kToolbarHeight + 12,
        20,
        28,
      ),
      children: [
        _GameCard(
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF111B2E),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF1E2A44)),
                ),
                child: Icon(
                  Icons.sports_esports,
                  color: widget.subject.accentColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Game Zone',
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
                      widget.subject.name,
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
        ),
        const SizedBox(height: 16),
        _GameCard(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showSubjectGamePicker(context, subjectChapter),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111B2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E2A44)),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Play Whole Subject',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Use all chapters for questions and rewards.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Choose a chapter to play',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 12),
        if (widget.subject.chapters.isEmpty)
          Text(
            'No chapters available yet.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          )
        else
          ...widget.subject.chapters.map(
            (chapter) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GameCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _showGamePicker(context, chapter),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF111B2E),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1E2A44)),
                        ),
                        child: Icon(
                          Icons.games,
                          color: widget.subject.accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chapter.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to choose a game mode',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white54),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showGamePicker(BuildContext context, Chapter chapter) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Play ${chapter.title}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 12),
              _buildGameOption(
                context,
                title: 'Study Survivor',
                subtitle: 'Survive waves and answer questions.',
                icon: Icons.shield,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SurvivalQuizGameScreen(
                        subject: widget.subject,
                        chapter: chapter,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildGameOption(
                context,
                title: 'Battle Quiz',
                subtitle: 'Challenge others in a live quiz battle.',
                icon: Icons.sports_esports,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BattleQuizScreen(
                        subject: widget.subject,
                        chapter: chapter,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildGameOption(
                context,
                title: 'Flashcards',
                subtitle: 'Quick revision with flashcards.',
                icon: Icons.auto_stories,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FlashcardsScreen(
                        subject: widget.subject,
                        chapter: chapter,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSubjectGamePicker(
    BuildContext context,
    Chapter subjectChapter,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Play ${widget.subject.name}',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 12),
              _buildGameOption(
                context,
                title: 'Study Survivor',
                subtitle: 'All chapters, one survival run.',
                icon: Icons.shield,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SurvivalQuizGameScreen(
                        subject: widget.subject,
                        chapter: subjectChapter,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildGameOption(
                context,
                title: 'Battle Quiz',
                subtitle: 'Quiz battle using the full subject.',
                icon: Icons.sports_esports,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BattleQuizScreen(
                        subject: widget.subject,
                        chapter: subjectChapter,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildGameOption(
                context,
                title: 'Subject Flashcards',
                subtitle: 'Flashcards from all chapters.',
                icon: Icons.auto_stories,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SubjectFlashcardsScreen(
                        subject: widget.subject,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return _GameCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF0B1220),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E2A44)),
              ),
              child: Icon(icon, color: const Color(0xFF38BDF8)),
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
                        .titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w600,
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
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
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

  Widget _inlineButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF38BDF8),
            Color(0xFF4F46E5),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
      ),
    );
  }

  void _openSyllabus(BuildContext context, String title, String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid syllabus link.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SyllabusWebViewScreen(title: title, url: uri.toString()),
      ),
    );
  }

}

class _SubjectBackdrop extends StatelessWidget {
  const _SubjectBackdrop();

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
          Positioned.fill(child: CustomPaint(painter: _SubjectGridPainter())),
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

class _SubjectGridPainter extends CustomPainter {
  const _SubjectGridPainter();

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
  bool shouldRepaint(covariant _SubjectGridPainter oldDelegate) => false;
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
