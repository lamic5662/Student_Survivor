import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/section_header.dart';
import 'package:student_survivor/features/syllabus/syllabus_webview_screen.dart';

class ProgrammingWorldScreen extends StatelessWidget {
  const ProgrammingWorldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Programming World'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeroCard(),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Learning Tracks'),
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
          const SectionHeader(title: 'Daily Practice'),
          const SizedBox(height: 12),
          const _PracticeCard(),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Project Ideas'),
          const SizedBox(height: 12),
          const _ProjectIdeas(),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Free Resources'),
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
          const SectionHeader(title: 'Pro Tips'),
          const SizedBox(height: 12),
          const _TipsCard(),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withValues(alpha: 0.18),
            AppColors.accent.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Build skills that matter',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your personal programming hub with tracks, practice, and projects.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedInk),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.mutedInk),
          ),
          const SizedBox(height: 10),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step,
                      style: Theme.of(context).textTheme.bodySmall,
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today’s plan',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mini projects you can build',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
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
    return AppCard(
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
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.open_in_new_rounded,
                      color: AppColors.secondary),
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
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.mutedInk),
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
    return AppCard(
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
          const Text('•  '),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
