import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/data/app_state.dart';
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
  bool _isGenerating = false;
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

  Future<void> _generatePlan() async {
    if (_isGenerating) return;
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });
    try {
      final subjects = AppState.profile.value.subjects;
      final plan = await _plannerService.generatePlan(
        subjects: subjects,
        days: 7,
        replaceExisting: true,
      );
      if (!mounted) return;
      setState(() {
        _days = plan;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to generate plan: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _openAddTaskSheet() async {
    final subjects = AppState.profile.value.subjects;
    final titleController = TextEditingController();
    Subject? selectedSubject;
    DateTime? dueDate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Study Task',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Task title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Subject>(
                    initialValue: selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Subject (optional)',
                    ),
                    items: subjects
                        .map(
                          (subject) => DropdownMenuItem(
                            value: subject,
                            child: Text(subject.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setSheetState(() {
                        selectedSubject = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dueDate == null
                              ? 'No due date'
                              : 'Due: ${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.mutedInk),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setSheetState(() {
                              dueDate = picked;
                            });
                          }
                        },
                        child: const Text('Pick Date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          return;
                        }
                        Navigator.of(context).pop();
                        await _plannerService.addTask(
                          title: title,
                          subjectId: selectedSubject?.id,
                          dueDate: dueDate,
                        );
                        await _load();
                      },
                      child: const Text('Save Task'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openEditTaskSheet(StudyTask task) async {
    final subjects = AppState.profile.value.subjects;
    final titleController = TextEditingController(text: task.title);
    Subject? selectedSubject;
    for (final subject in subjects) {
      if (subject.name == task.subject) {
        selectedSubject = subject;
        break;
      }
    }

    DateTime? dueDate;
    for (final day in _days) {
      if (day.tasks.contains(task)) {
        final parsed = DateTime.tryParse(day.label);
        if (parsed != null) {
          dueDate = parsed;
        }
        break;
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Task',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Task title',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Subject>(
                    initialValue: selectedSubject,
                    decoration: const InputDecoration(
                      labelText: 'Subject (optional)',
                    ),
                    items: subjects
                        .map(
                          (subject) => DropdownMenuItem(
                            value: subject,
                            child: Text(subject.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setSheetState(() {
                        selectedSubject = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dueDate == null
                              ? 'No due date'
                              : 'Due: ${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.mutedInk),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 1)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setSheetState(() {
                              dueDate = picked;
                            });
                          }
                        },
                        child: const Text('Pick Date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        if (title.isEmpty) {
                          return;
                        }
                        Navigator.of(context).pop();
                        await _plannerService.updateTask(
                          taskId: task.id,
                          title: title,
                          subjectId: selectedSubject?.id,
                          dueDate: dueDate,
                        );
                        await _load();
                      },
                      child: const Text('Update Task'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Planner'),
        actions: [
          IconButton(
            onPressed: _openAddTaskSheet,
            icon: const Icon(Icons.add),
            tooltip: 'Add task',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Study Plan',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate a 7-day plan from your subjects.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isGenerating ? null : _generatePlan,
                    child: Text(
                      _isGenerating ? 'Generating...' : 'Generate Plan',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
                        onEdit: task.id.isEmpty
                            ? null
                            : () => _openEditTaskSheet(task),
                        onDelete: task.id.isEmpty
                            ? null
                            : () async {
                                await _plannerService.deleteTask(task.id);
                                await _load();
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
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TaskTile({
    required this.task,
    required this.isDone,
    required this.onChanged,
    this.onEdit,
    this.onDelete,
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
        if (onEdit != null)
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            color: AppColors.mutedInk,
          ),
        if (onDelete != null)
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            color: AppColors.mutedInk,
          ),
      ],
    );
  }
}
