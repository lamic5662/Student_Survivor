import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/data/planner_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/app_models.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late final PlannerService _plannerService;
  bool _isLoading = true;
  String? _errorMessage;
  List<StudyPlanDay> _days = const [];

  @override
  void initState() {
    super.initState();
    _plannerService = PlannerService(SupabaseConfig.client);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final plan = await _plannerService.fetchPlan();
      if (!mounted) return;
      setState(() {
        _days = plan;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load plan: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Planner'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Text(_errorMessage!)
          else if (_days.isEmpty)
            const Text('No study tasks yet. Create a plan to get started.')
          else
            ..._days.map(
              (day) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.label,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                    ...day.tasks.map(
                      (task) => _TaskTile(
                        task: task,
                        isDone: task.isDone,
                        onChanged: (value) async {
                          final done = value == true;
                          setState(() {
                            day.tasks[day.tasks.indexOf(task)] = StudyTask(
                              id: task.id,
                              title: task.title,
                              subject: task.subject,
                              isDone: done,
                            );
                          });
                          if (task.id.isNotEmpty) {
                            await _plannerService.setTaskDone(
                              taskId: task.id,
                              isDone: done,
                            );
                          }
                        },
                      ),
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

class _TaskTile extends StatelessWidget {
  final StudyTask task;
  final bool isDone;
  final ValueChanged<bool?> onChanged;

  const _TaskTile({
    required this.task,
    required this.isDone,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: isDone,
          onChanged: onChanged,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      decoration: isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                task.subject,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.mutedInk),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}
