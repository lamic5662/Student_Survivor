import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/data/mock_data.dart';
import 'package:student_survivor/models/app_models.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late final Set<String> _doneTasks;

  @override
  void initState() {
    super.initState();
    _doneTasks = {
      for (final day in MockData.planner)
        for (final task in day.tasks)
          if (task.isDone) task.title,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Planner'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: MockData.planner
            .map(
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
                      ...day.tasks.map((task) => _TaskTile(
                            task: task,
                            isDone: _doneTasks.contains(task.title),
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _doneTasks.add(task.title);
                                } else {
                                  _doneTasks.remove(task.title);
                                }
                              });
                            },
                          )),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
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
