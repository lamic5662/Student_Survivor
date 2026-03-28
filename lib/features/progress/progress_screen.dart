import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
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
  Map<String, double> _subjectProgress = const {};
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _progressService = ProgressService(SupabaseConfig.client);
    _listener = _load;
    AppState.profile.addListener(_listener);
    _load();
  }

  @override
  void dispose() {
    AppState.profile.removeListener(_listener);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final subjects = AppState.profile.value.subjects;
      final overall = await _progressService.fetchOverallProgress(subjects);
      final subjectProgress =
          await _progressService.fetchSubjectProgress(subjects);
      if (!mounted) return;
      setState(() {
        _overall = overall;
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
      appBar: AppBar(
        title: const Text('Progress Tracking'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Text(_errorMessage!)
          else
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall completion',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _overall,
                    backgroundColor: AppColors.outline,
                    color: AppColors.secondary,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_overall * 100).round()}% of syllabus completed',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.mutedInk),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Subject progress',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (profile.subjects.isEmpty)
            const Text('Select a semester to track progress.')
          else
            ...profile.subjects.map(
              (subject) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _subjectProgress[subject.id] ?? 0,
                        backgroundColor: AppColors.outline,
                        color: subject.accentColor,
                        minHeight: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
