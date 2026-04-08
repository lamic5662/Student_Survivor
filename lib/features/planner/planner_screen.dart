import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/data/app_state.dart';
import 'package:student_survivor/data/planner_service.dart';
import 'package:student_survivor/data/subject_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/features/subjects/chapter_detail_screen.dart';
import 'package:student_survivor/models/app_models.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  static const _prefsTaskMeta = 'planner_task_meta';
  static const _prefsStudyMinutes = 'planner_study_minutes';
  static const _prefsStreak = 'planner_streak_days';
  static const _prefsLastStudy = 'planner_last_study';
  static const _prefsReminderEnabled = 'planner_reminder_enabled';
  static const _prefsReminderTime = 'planner_reminder_time';
  static const _prefsFocusMinutes = 'planner_focus_minutes';
  static const _prefsBreakMinutes = 'planner_break_minutes';
  static const List<int> _estimateOptions = [30, 45, 60, 90, 120];
  static const List<String> _priorityOptions = ['Low', 'Medium', 'High'];

  late final PlannerService _plannerService;
  late final SubjectService _subjectService;
  SharedPreferences? _prefs;
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isNotesLoading = false;
  String? _errorMessage;
  List<StudyPlanDay> _days = const [];
  final Map<String, _TaskMeta> _taskMeta = {};
  Map<String, List<_NoteSuggestion>> _subjectNotes = {};

  String _subjectFilter = 'All';
  String _rangeFilter = 'This Week';
  DateTime? _selectedDate;

  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

  int _focusMinutes = 25;
  int _breakMinutes = 5;
  Duration _focusRemaining = const Duration(minutes: 25);
  bool _focusRunning = false;
  bool _inBreak = false;
  Timer? _focusTimer;
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;

  int _studiedMinutes = 0;
  int _streakDays = 0;
  DateTime? _lastStudyDate;

  @override
  void initState() {
    super.initState();
    _plannerService = PlannerService(SupabaseConfig.client);
    _subjectService = SubjectService(SupabaseConfig.client);
    _loadLocalPrefs();
    _load();
    _loadNoteSuggestions();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void reassemble() {
    super.reassemble();
    // Ensure type-safe map after hot reload changes.
    _subjectNotes = {};
    _loadNoteSuggestions();
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
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
      final plan = await _plannerService.fetchPlan();
      if (!mounted) return;
      setState(() {
        _days = plan;
        _isLoading = false;
      });
      _ensureMetaForTasks(plan);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr(
          'Failed to load plan: $error',
          'योजना लोड गर्न असफल: $error',
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final metaJson = prefs.getString(_prefsTaskMeta);
    if (metaJson != null && metaJson.isNotEmpty) {
      final decoded = Map<String, dynamic>.from(jsonDecode(metaJson));
      decoded.forEach((key, value) {
        final data = Map<String, dynamic>.from(value as Map);
        _taskMeta[key] = _TaskMeta(
          estimateMinutes: data['estimate'] as int? ?? 30,
          priority: data['priority']?.toString() ?? 'Medium',
          remind: data['remind'] as bool? ?? false,
        );
      });
    }
    _studiedMinutes = prefs.getInt(_prefsStudyMinutes) ?? 0;
    _streakDays = prefs.getInt(_prefsStreak) ?? 0;
    final lastStudy = prefs.getString(_prefsLastStudy);
    _lastStudyDate = lastStudy == null ? null : DateTime.tryParse(lastStudy);
    _reminderEnabled = prefs.getBool(_prefsReminderEnabled) ?? true;
    final reminderTime = prefs.getString(_prefsReminderTime);
    if (reminderTime != null && reminderTime.contains(':')) {
      final parts = reminderTime.split(':');
      final hour = int.tryParse(parts[0]) ?? 20;
      final minute = int.tryParse(parts[1]) ?? 0;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
    }
    _focusMinutes = prefs.getInt(_prefsFocusMinutes) ?? 25;
    _breakMinutes = prefs.getInt(_prefsBreakMinutes) ?? 5;
    _focusRemaining = Duration(minutes: _focusMinutes);
    _prefs = prefs;
    if (mounted) {
      setState(() {});
    }
  }

  void _ensureMetaForTasks(List<StudyPlanDay> plan) {
    var updated = false;
    for (final day in plan) {
      for (final task in day.tasks) {
        if (task.id.isEmpty) continue;
        if (_taskMeta.containsKey(task.id)) continue;
        _taskMeta[task.id] = const _TaskMeta(
          estimateMinutes: 30,
          priority: 'Medium',
          remind: false,
        );
        updated = true;
      }
    }
    if (updated) {
      _persistTaskMeta();
    }
  }

  void _persistTaskMeta() {
    final prefs = _prefs;
    if (prefs == null) return;
    final encoded = jsonEncode(
      _taskMeta.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    );
    prefs.setString(_prefsTaskMeta, encoded);
  }

  void _persistStats() {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setInt(_prefsStudyMinutes, _studiedMinutes);
    prefs.setInt(_prefsStreak, _streakDays);
    if (_lastStudyDate != null) {
      prefs.setString(_prefsLastStudy, _lastStudyDate!.toIso8601String());
    }
  }

  void _persistSettings() {
    final prefs = _prefs;
    if (prefs == null) return;
    prefs.setBool(_prefsReminderEnabled, _reminderEnabled);
    prefs.setString(
      _prefsReminderTime,
      '${_reminderTime.hour.toString().padLeft(2, '0')}:${_reminderTime.minute.toString().padLeft(2, '0')}',
    );
    prefs.setInt(_prefsFocusMinutes, _focusMinutes);
    prefs.setInt(_prefsBreakMinutes, _breakMinutes);
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
      _ensureMetaForTasks(plan);
      _loadNoteSuggestions();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr(
          'Failed to generate plan: $error',
          'योजना बनाउन असफल: $error',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  static const int _notesSuggestionLimit = 5;

  Future<void> _loadNoteSuggestions() async {
    if (_isNotesLoading) return;
    setState(() {
      _isNotesLoading = true;
    });
    try {
      final subjects = await _subjectService.fetchUserSubjects(
        includeContent: true,
      );
      if (!mounted) return;
      final Map<String, List<_NoteSuggestion>> notesBySubject = {};
      for (final subject in subjects) {
        final suggestions = <_NoteSuggestion>[];
        for (final chapter in subject.chapters) {
          for (final note in chapter.notes) {
            suggestions.add(
              _NoteSuggestion(
                subject: subject,
                chapter: chapter,
                note: note,
              ),
            );
            if (suggestions.length >= _notesSuggestionLimit) break;
          }
          if (suggestions.length >= _notesSuggestionLimit) break;
        }
        if (suggestions.isNotEmpty) {
          notesBySubject[subject.name] = suggestions;
        }
      }
      setState(() {
        _subjectNotes = notesBySubject;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _subjectNotes = {};
      });
    } finally {
      if (mounted) {
        setState(() {
          _isNotesLoading = false;
        });
      }
    }
  }

  Future<void> _openAddTaskSheet() async {
    final subjects = AppState.profile.value.subjects;
    final titleController = TextEditingController();
    Subject? selectedSubject;
    DateTime? dueDate;
    var estimate = _estimateOptions.first;
    var priority = _priorityOptions[1];
    var remind = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                    context.tr('Add Study Task', 'अध्ययन कार्य थप्नुहोस्'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _darkInputDecoration(
                      context.tr('Task title', 'कार्य शीर्षक'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Subject>(
                    initialValue: selectedSubject,
                    decoration: _darkInputDecoration(
                      context.tr('Subject (optional)', 'विषय (वैकल्पिक)'),
                    ),
                    dropdownColor: const Color(0xFF0B1220),
                    style: const TextStyle(color: Colors.white),
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
                  DropdownButtonFormField<int>(
                    initialValue: estimate,
                    decoration: _darkInputDecoration(
                      context.tr('Time estimate', 'समय अनुमान'),
                    ),
                    dropdownColor: const Color(0xFF0B1220),
                    style: const TextStyle(color: Colors.white),
                    items: _estimateOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child:
                                Text(context.tr('$value min', '$value मिनेट')),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setSheetState(() {
                        estimate = value ?? estimate;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: _darkInputDecoration(
                      context.tr('Priority', 'प्राथमिकता'),
                    ),
                    dropdownColor: const Color(0xFF0B1220),
                    style: const TextStyle(color: Colors.white),
                    items: _priorityOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_priorityLabel(context, value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setSheetState(() {
                        priority = value ?? priority;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      context.tr('Reminder', 'रिमाइन्डर'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      context.tr(
                        'Get a reminder for this task',
                        'यस कार्यको लागि रिमाइन्डर पाउनुहोस्',
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    value: remind,
                    onChanged: (value) {
                      setSheetState(() {
                        remind = value;
                      });
                    },
                    activeThumbColor: const Color(0xFF38BDF8),
                    activeTrackColor:
                        const Color(0xFF38BDF8).withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dueDate == null
                              ? context.tr('No due date', 'म्याद छैन')
                              : context.tr(
                                  'Due: ${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
                                  'म्याद: ${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
                                ),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
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
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child:
                            Text(context.tr('Pick Date', 'मिति छान्नुहोस्')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PrimaryActionButton(
                    label: context.tr('Save Task', 'कार्य सुरक्षित गर्नुहोस्'),
                    enabled: true,
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        return;
                      }
                      Navigator.of(context).pop();
                      final id = await _plannerService.addTask(
                        title: title,
                        subjectId: selectedSubject?.id,
                        dueDate: dueDate,
                      );
                      if (id.isNotEmpty) {
                        _taskMeta[id] = _TaskMeta(
                          estimateMinutes: estimate,
                          priority: priority,
                          remind: remind,
                        );
                        _persistTaskMeta();
                      }
                      await _load();
                    },
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
    if (task.dueDate != null) {
      dueDate = DateTime.tryParse(task.dueDate!);
    }
    final meta = _taskMeta[task.id] ??
        const _TaskMeta(estimateMinutes: 30, priority: 'Medium', remind: false);
    var estimate = meta.estimateMinutes;
    var priority = meta.priority;
    var remind = meta.remind;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                    context.tr('Edit Task', 'कार्य सम्पादन'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _darkInputDecoration(
                      context.tr('Task title', 'कार्य शीर्षक'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Subject>(
                    initialValue: selectedSubject,
                    decoration: _darkInputDecoration(
                      context.tr('Subject (optional)', 'विषय (वैकल्पिक)'),
                    ),
                    dropdownColor: const Color(0xFF0B1220),
                    style: const TextStyle(color: Colors.white),
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
                  DropdownButtonFormField<int>(
                    initialValue: estimate,
                    decoration: _darkInputDecoration(
                      context.tr('Time estimate', 'समय अनुमान'),
                    ),
                    dropdownColor: const Color(0xFF0B1220),
                    style: const TextStyle(color: Colors.white),
                    items: _estimateOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child:
                                Text(context.tr('$value min', '$value मिनेट')),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setSheetState(() {
                        estimate = value ?? estimate;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: _darkInputDecoration(
                      context.tr('Priority', 'प्राथमिकता'),
                    ),
                    dropdownColor: const Color(0xFF0B1220),
                    style: const TextStyle(color: Colors.white),
                    items: _priorityOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_priorityLabel(context, value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setSheetState(() {
                        priority = value ?? priority;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      context.tr('Reminder', 'रिमाइन्डर'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      context.tr(
                        'Get a reminder for this task',
                        'यस कार्यको लागि रिमाइन्डर पाउनुहोस्',
                      ),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    value: remind,
                    onChanged: (value) {
                      setSheetState(() {
                        remind = value;
                      });
                    },
                    activeThumbColor: const Color(0xFF38BDF8),
                    activeTrackColor:
                        const Color(0xFF38BDF8).withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dueDate == null
                              ? context.tr('No due date', 'म्याद छैन')
                              : context.tr(
                                  'Due: ${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
                                  'म्याद: ${dueDate!.year}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}',
                                ),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
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
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child:
                            Text(context.tr('Pick Date', 'मिति छान्नुहोस्')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _PrimaryActionButton(
                    label:
                        context.tr('Update Task', 'कार्य अपडेट गर्नुहोस्'),
                    enabled: true,
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
                      _taskMeta[task.id] = _TaskMeta(
                        estimateMinutes: estimate,
                        priority: priority,
                        remind: remind,
                      );
                      _persistTaskMeta();
                      await _load();
                    },
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

  void _startFocus() {
    if (_focusRunning) return;
    setState(() {
      _focusRunning = true;
    });
    _focusTimer?.cancel();
    _focusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_focusRemaining.inSeconds <= 1) {
        timer.cancel();
        _focusRunning = false;
        if (!_inBreak) {
          _completeFocusSession();
          if (_breakMinutes > 0) {
            setState(() {
              _inBreak = true;
              _focusRemaining = Duration(minutes: _breakMinutes);
            });
            _startFocus();
          } else {
            _resetFocus();
          }
        } else {
          _resetFocus();
        }
      } else {
        setState(() {
          _focusRemaining -= const Duration(seconds: 1);
        });
      }
    });
  }

  void _pauseFocus() {
    _focusTimer?.cancel();
    setState(() {
      _focusRunning = false;
    });
  }

  void _resetFocus() {
    _focusTimer?.cancel();
    setState(() {
      _focusRunning = false;
      _inBreak = false;
      _focusRemaining = Duration(minutes: _focusMinutes);
    });
  }

  void _completeFocusSession() {
    _studiedMinutes += _focusMinutes;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (_lastStudyDate == null) {
      _streakDays = 1;
    } else {
      final last = DateTime(
        _lastStudyDate!.year,
        _lastStudyDate!.month,
        _lastStudyDate!.day,
      );
      final diff = todayDate.difference(last).inDays;
      if (diff == 0) {
        // same day, keep streak
      } else if (diff == 1) {
        _streakDays += 1;
      } else {
        _streakDays = 1;
      }
    }
    _lastStudyDate = todayDate;
    _persistStats();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'Focus session done! +$_focusMinutes min logged.',
            'फोकस सेसन पूरा! +$_focusMinutes मिनेट रेकर्ड भयो।',
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours > 0 ? '${duration.inHours}:' : ''}$minutes:$seconds';
  }

  DateTime? _taskDate(StudyTask task, String dayLabel) {
    if (task.dueDate != null) {
      return DateTime.tryParse(task.dueDate!);
    }
    if (dayLabel == 'Today') {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    if (dayLabel == 'Tomorrow') {
      final now = DateTime.now().add(const Duration(days: 1));
      return DateTime(now.year, now.month, now.day);
    }
    return DateTime.tryParse(dayLabel);
  }

  bool _matchesRange(DateTime? date) {
    if (_rangeFilter == 'All') {
      return true;
    }
    if (date == null) {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    if (_rangeFilter == 'Today') {
      return diff == 0;
    }
    if (_rangeFilter == 'This Week') {
      return diff >= 0 && diff <= 6;
    }
    return true;
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return AppColors.danger;
      case 'Low':
        return AppColors.success;
      case 'Medium':
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = AppState.profile.value.subjects;
    final subjectNames = ['All', ...subjects.map((s) => s.name)];
    final filteredDays = _days
        .map((day) {
          final tasks = day.tasks.where((task) {
            if (_subjectFilter != 'All' && task.subject != _subjectFilter) {
              return false;
            }
            final date = _taskDate(task, day.label);
            if (_selectedDate != null) {
              return date != null &&
                  date.year == _selectedDate!.year &&
                  date.month == _selectedDate!.month &&
                  date.day == _selectedDate!.day;
            }
            return _matchesRange(date);
          }).toList();
          return StudyPlanDay(label: day.label, tasks: tasks);
        })
        .where((day) => day.tasks.isNotEmpty)
        .toList();
    final totalTasks = filteredDays.fold<int>(
      0,
      (sum, day) => sum + day.tasks.length,
    );
    final doneTasks = filteredDays.fold<int>(
      0,
      (sum, day) => sum + day.tasks.where((t) => t.isDone).length,
    );
    final overallProgress =
        totalTasks == 0 ? 0.0 : doneTasks / totalTasks;

    final today = DateTime.now();
    final weekDates = List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day + index),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            context.l10n.studyPlanner,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _openAddTaskSheet,
            icon: const Icon(Icons.add),
            tooltip: context.tr('Add task', 'कार्य थप्नुहोस्'),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _PlannerBackdrop()),
          ListView(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + kToolbarHeight + 12,
              20,
              28,
            ),
            children: [
              _PlannerHero(
                progress: overallProgress,
                totalTasks: totalTasks,
                doneTasks: doneTasks,
                semesterName: AppState.profile.value.semester.name,
              ),
              const SizedBox(height: 16),
              _FilterRow(
                subjectNames: subjectNames,
                selectedSubject: _subjectFilter,
                rangeFilter: _rangeFilter,
                onSubjectChanged: (value) {
                  setState(() {
                    _subjectFilter = value;
                  });
                },
                onRangeChanged: (value) {
                  setState(() {
                    _rangeFilter = value;
                    _selectedDate = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              _WeekStrip(
                dates: weekDates,
                selectedDate: _selectedDate,
                countForDate: (date) {
                  var count = 0;
                  for (final day in _days) {
                    for (final task in day.tasks) {
                      if (_subjectFilter != 'All' &&
                          task.subject != _subjectFilter) {
                        continue;
                      }
                      final taskDate = _taskDate(task, day.label);
                      if (taskDate == null) continue;
                      if (taskDate.year == date.year &&
                          taskDate.month == date.month &&
                          taskDate.day == date.day) {
                        count += 1;
                      }
                    }
                  }
                  return count;
                },
                onSelect: (date) {
                  setState(() {
                    if (_selectedDate != null &&
                        _selectedDate!.year == date.year &&
                        _selectedDate!.month == date.month &&
                        _selectedDate!.day == date.day) {
                      _selectedDate = null;
                    } else {
                      _selectedDate = date;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              _StatsRow(
                studiedMinutes: _studiedMinutes,
                streakDays: _streakDays,
              ),
              const SizedBox(height: 16),
              _FocusSessionCard(
                focusMinutes: _focusMinutes,
                breakMinutes: _breakMinutes,
                remaining: _focusRemaining,
                running: _focusRunning,
                inBreak: _inBreak,
                onStart: _startFocus,
                onPause: _pauseFocus,
                onReset: _resetFocus,
                onChangeFocus: (value) {
                  setState(() {
                    _focusMinutes = value;
                    if (!_focusRunning && !_inBreak) {
                      _focusRemaining = Duration(minutes: _focusMinutes);
                    }
                  });
                  _persistSettings();
                },
                onChangeBreak: (value) {
                  setState(() {
                    _breakMinutes = value;
                  });
                  _persistSettings();
                },
                formatDuration: _formatDuration,
              ),
              const SizedBox(height: 16),
              _ReminderCard(
                enabled: _reminderEnabled,
                time: _reminderTime,
                onToggle: (value) {
                  setState(() {
                    _reminderEnabled = value;
                  });
                  _persistSettings();
                },
                onPickTime: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _reminderTime,
                  );
                  if (picked != null) {
                    setState(() {
                      _reminderTime = picked;
                    });
                    _persistSettings();
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_isNotesLoading)
                _GameCard(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr(
                            'Loading note suggestions...',
                            'नोट सुझावहरू लोड हुँदैछन्...',
                          ),
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _SubjectNotesCard(notesBySubject: _subjectNotes),
              const SizedBox(height: 16),
              _GameCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('AI Study Plan', 'AI अध्ययन योजना'),
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
                      context.tr(
                        'Generate a 7-day plan from your subjects.',
                        'आफ्ना विषयबाट ७-दिनको योजना बनाउनुहोस्।',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _PrimaryActionButton(
                        label:
                            _isGenerating
                                ? context.tr('Generating...', 'बनाइँदैछ...')
                                : context.tr('Generate Plan', 'योजना बनाउनुहोस्'),
                        enabled: !_isGenerating,
                        onPressed: _isGenerating ? null : _generatePlan,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                          style: const TextStyle(color: Color(0xFFF87171)),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_days.isEmpty)
                Text(
                  context.tr(
                    'No study tasks yet. Create a plan to get started.',
                    'अहिलेसम्म अध्ययन कार्य छैन। सुरु गर्न योजना बनाउनुहोस्।',
                  ),
                  style: const TextStyle(color: Colors.white70),
                )
              else if (filteredDays.isEmpty)
                Text(
                  context.tr(
                    'No tasks match your filters.',
                    'तपाईंका फिल्टरसँग मेल खाने कार्य छैनन्।',
                  ),
                  style: const TextStyle(color: Colors.white70),
                )
              else
                ...filteredDays.map(
                  (day) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _TaskGroupCard(
                      label: day.label,
                      tasks: day.tasks,
                      metaFor: (task) => _taskMeta[task.id],
                      priorityColor: _priorityColor,
                      onToggle: (task, value) async {
                        final done = value == true;
                        setState(() {
                          day.tasks[day.tasks.indexOf(task)] = StudyTask(
                            id: task.id,
                            title: task.title,
                            subject: task.subject,
                            isDone: done,
                            dueDate: task.dueDate,
                          );
                        });
                        if (task.id.isNotEmpty) {
                          await _plannerService.setTaskDone(
                            taskId: task.id,
                            isDone: done,
                          );
                        }
                      },
                      onEdit: (task) => _openEditTaskSheet(task),
                      onDelete: (task) async {
                        await _plannerService.deleteTask(task.id);
                        _taskMeta.remove(task.id);
                        _persistTaskMeta();
                        await _load();
                      },
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

class _TaskTile extends StatelessWidget {
  final StudyTask task;
  final bool isDone;
  final _TaskMeta meta;
  final Color priorityColor;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TaskTile({
    required this.task,
    required this.isDone,
    required this.meta,
    required this.priorityColor,
    required this.onChanged,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dueDate = task.dueDate != null
        ? DateTime.tryParse(task.dueDate!)
        : null;
    return Row(
      children: [
        Checkbox(
          value: isDone,
          onChanged: onChanged,
          activeColor: const Color(0xFF38BDF8),
          checkColor: Colors.white,
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
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
              ),
              if (task.subject.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.subject,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(
                    icon: Icons.timer,
                    label: context.tr(
                      '${meta.estimateMinutes} min',
                      '${meta.estimateMinutes} मिनेट',
                    ),
                    color: AppColors.accent,
                  ),
                  _MetaChip(
                    icon: Icons.flag,
                    label: _priorityLabel(context, meta.priority),
                    color: priorityColor,
                  ),
                  if (dueDate != null)
                    _MetaChip(
                      icon: Icons.event,
                      label: context.tr(
                        'Due ${_shortDate(context, dueDate)}',
                        'म्याद ${_shortDate(context, dueDate)}',
                      ),
                      color: AppColors.secondary,
                    ),
                  if (meta.remind)
                    _MetaChip(
                      icon: Icons.notifications_active,
                      label: context.tr('Reminder', 'रिमाइन्डर'),
                      color: AppColors.warning,
                    ),
                ],
              ),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            color: Colors.white54,
          ),
        if (onDelete != null)
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            color: Colors.white54,
          ),
      ],
    );
  }
}

class _TaskMeta {
  final int estimateMinutes;
  final String priority;
  final bool remind;

  const _TaskMeta({
    required this.estimateMinutes,
    required this.priority,
    required this.remind,
  });

  Map<String, dynamic> toJson() => {
        'estimate': estimateMinutes,
        'priority': priority,
        'remind': remind,
      };
}

class _PlannerHero extends StatelessWidget {
  final double progress;
  final int totalTasks;
  final int doneTasks;
  final String semesterName;

  const _PlannerHero({
    required this.progress,
    required this.totalTasks,
    required this.doneTasks,
    required this.semesterName,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Study Planner', 'स्टडी प्लानर'),
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
                      context.tr(
                        'Semester: $semesterName',
                        'सेमेस्टर: $semesterName',
                      ),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF111B2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E2A44)),
                ),
                child: Text(
                  '$percent%',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: const Color(0xFF1E2A44),
            color: const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr(
              '$doneTasks of $totalTasks tasks completed',
              '$doneTasks / $totalTasks कार्य पूरा',
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

class _FilterRow extends StatelessWidget {
  final List<String> subjectNames;
  final String selectedSubject;
  final String rangeFilter;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<String> onRangeChanged;

  const _FilterRow({
    required this.subjectNames,
    required this.selectedSubject,
    required this.rangeFilter,
    required this.onSubjectChanged,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Filters', 'फिल्टरहरू'),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedSubject,
            isExpanded: true,
            decoration: _darkInputDecoration(
              context.tr('Subject', 'विषय'),
            ),
            dropdownColor: const Color(0xFF0B1220),
            style: const TextStyle(color: Colors.white),
            items: subjectNames
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                      value == 'All' ? context.tr('All', 'सबै') : value,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                onSubjectChanged(value);
              }
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['Today', 'This Week', 'All']
                .map(
                  (label) => ChoiceChip(
                    label: Text(_rangeLabel(context, label)),
                    selected: rangeFilter == label,
                    onSelected: (_) => onRangeChanged(label),
                    selectedColor: const Color(0xFF38BDF8),
                    backgroundColor: const Color(0xFF111B2E),
                    side: const BorderSide(color: Color(0xFF1E2A44)),
                    labelStyle: TextStyle(
                      color:
                          rangeFilter == label ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final List<DateTime> dates;
  final DateTime? selectedDate;
  final int Function(DateTime) countForDate;
  final ValueChanged<DateTime> onSelect;

  const _WeekStrip({
    required this.dates,
    required this.selectedDate,
    required this.countForDate,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('This Week', 'यस हप्ता'),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 78,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dates.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final date = dates[index];
                final isSelected = selectedDate != null &&
                    date.year == selectedDate!.year &&
                    date.month == selectedDate!.month &&
                    date.day == selectedDate!.day;
                final count = countForDate(date);
                return InkWell(
                  onTap: () => onSelect(date),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 72,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0B1220),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1E2A44)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _weekdayShort(context, date),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${date.day}',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color:
                                    isSelected ? Colors.white : Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('$count tasks', '$count कार्य'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: isSelected
                                    ? Colors.white70
                                    : Colors.white54,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int studiedMinutes;
  final int streakDays;

  const _StatsRow({
    required this.studiedMinutes,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GameCard(
            child: _StatTile(
              label: context.tr('Study Minutes', 'अध्ययन मिनेट'),
              value: '$studiedMinutes',
              icon: Icons.timer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GameCard(
            child: _StatTile(
              label: context.tr('Streak Days', 'स्ट्रिक दिन'),
              value: '$streakDays',
              icon: Icons.local_fire_department,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF111B2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E2A44)),
          ),
          child: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FocusSessionCard extends StatelessWidget {
  final int focusMinutes;
  final int breakMinutes;
  final Duration remaining;
  final bool running;
  final bool inBreak;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final ValueChanged<int> onChangeFocus;
  final ValueChanged<int> onChangeBreak;
  final String Function(Duration) formatDuration;

  const _FocusSessionCard({
    required this.focusMinutes,
    required this.breakMinutes,
    required this.remaining,
    required this.running,
    required this.inBreak,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.onChangeFocus,
    required this.onChangeBreak,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final totalSeconds =
        (inBreak ? breakMinutes : focusMinutes) * 60;
    final progress = totalSeconds == 0
        ? 0.0
        : remaining.inSeconds / totalSeconds;
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Focus Session', 'फोकस सेसन'),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: inBreak
                      ? const Color(0xFF3A2A12)
                      : const Color(0xFF111B2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E2A44)),
                ),
                child: Text(
                  inBreak
                      ? context.tr('Break', 'ब्रेक')
                      : context.tr('Focus', 'फोकस'),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: inBreak
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF38BDF8),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatDuration(remaining),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: const Color(0xFF1E2A44),
            color: inBreak
                ? const Color(0xFFF59E0B)
                : const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                onPressed: running ? onPause : onStart,
                icon: Icon(running ? Icons.pause : Icons.play_arrow),
                label: Text(
                  running
                      ? context.tr('Pause', 'पज')
                      : context.tr('Start', 'सुरु'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt),
                label: Text(context.tr('Reset', 'रिसेट')),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: focusMinutes,
                  decoration: _darkInputDecoration(
                    context.tr('Focus', 'फोकस'),
                  ),
                  dropdownColor: const Color(0xFF0B1220),
                  style: const TextStyle(color: Colors.white),
                  items: const [15, 20, 25, 30, 45]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child:
                              Text(context.tr('$value min', '$value मिनेट')),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onChangeFocus(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: breakMinutes,
                  decoration: _darkInputDecoration(
                    context.tr('Break', 'ब्रेक'),
                  ),
                  dropdownColor: const Color(0xFF0B1220),
                  style: const TextStyle(color: Colors.white),
                  items: const [0, 5, 10, 15]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child:
                              Text(context.tr('$value min', '$value मिनेट')),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      onChangeBreak(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final bool enabled;
  final TimeOfDay time;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  const _ReminderCard({
    required this.enabled,
    required this.time,
    required this.onToggle,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Daily Reminder', 'दैनिक रिमाइन्डर'),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: const Color(0xFF38BDF8),
                activeTrackColor:
                    const Color(0xFF38BDF8).withValues(alpha: 0.35),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            enabled
                ? context.tr(
                    'We will remind you at ${time.format(context)}',
                    '${time.format(context)} मा सम्झाइनेछ',
                  )
                : context.tr('Reminders are off', 'रिमाइन्डर बन्द छ'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: enabled ? onPickTime : null,
              icon: const Icon(Icons.schedule),
              label: Text(context.tr('Pick Time', 'समय छान्नुहोस्')),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectNotesCard extends StatelessWidget {
  final Map<String, List<_NoteSuggestion>> notesBySubject;

  const _SubjectNotesCard({
    required this.notesBySubject,
  });

  @override
  Widget build(BuildContext context) {
    if (notesBySubject.isEmpty) {
      return _GameCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Notes Suggestions', 'नोट सुझावहरू'),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'No notes available yet. Add notes to see suggestions here.',
                'अहिलेसम्म नोटहरू उपलब्ध छैनन्। सुझाव हेर्न नोट थप्नुहोस्।',
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

    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Notes Suggestions', 'नोट सुझावहरू'),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 12),
          ...notesBySubject.entries.map(
            (entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: entry.value
                          .map(
                            (suggestion) => _NoteChip(
                              title: suggestion.note.title,
                              subtitle: suggestion.chapter.title,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChapterDetailScreen(
                                      subject: suggestion.subject,
                                      chapter: suggestion.chapter,
                                      useGameZoneTheme: false,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NoteChip extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NoteChip({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF111B2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E2A44)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF38BDF8),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteSuggestion {
  final Subject subject;
  final Chapter chapter;
  final Note note;

  const _NoteSuggestion({
    required this.subject,
    required this.chapter,
    required this.note,
  });
}

class _TaskGroupCard extends StatelessWidget {
  final String label;
  final List<StudyTask> tasks;
  final _TaskMeta? Function(StudyTask task) metaFor;
  final Color Function(String) priorityColor;
  final Future<void> Function(StudyTask task, bool? value) onToggle;
  final ValueChanged<StudyTask> onEdit;
  final ValueChanged<StudyTask> onDelete;

  const _TaskGroupCard({
    required this.label,
    required this.tasks,
    required this.metaFor,
    required this.priorityColor,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final done = tasks.where((task) => task.isDone).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    final formattedLabel = _formatDayLabel(context, label);
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formattedLabel,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                ),
              ),
              Text(
                '$done/${tasks.length}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: const Color(0xFF1E2A44),
            color: const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 12),
          ...tasks.asMap().entries.map(
                (entry) {
                  final index = entry.key;
                  final task = entry.value;
                  final meta = metaFor(task) ??
                      const _TaskMeta(
                        estimateMinutes: 30,
                        priority: 'Medium',
                        remind: false,
                      );
                  return Column(
                    children: [
                      _TaskTile(
                        task: task,
                        isDone: task.isDone,
                        meta: meta,
                        priorityColor: priorityColor(meta.priority),
                        onChanged: (value) => onToggle(task, value),
                        onEdit: () => onEdit(task),
                        onDelete: () => onDelete(task),
                      ),
                      if (index != tasks.length - 1)
                        const Divider(
                          height: 20,
                          color: Color(0xFF1E2A44),
                        ),
                    ],
                  );
                },
              ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String _weekdayShort(BuildContext context, DateTime date) {
  const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const ne = ['सोम', 'मंगल', 'बुध', 'बिहि', 'शुक्र', 'शनि', 'आइत'];
  final isNe = Localizations.localeOf(context).languageCode == 'ne';
  return (isNe ? ne : en)[date.weekday - 1];
}

String _shortDate(BuildContext context, DateTime date) {
  const en = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const ne = [
    'जन',
    'फेब',
    'मार',
    'अप्र',
    'मे',
    'जुन',
    'जुल',
    'अग',
    'सेप',
    'अक्ट',
    'नोभ',
    'डिस',
  ];
  final isNe = Localizations.localeOf(context).languageCode == 'ne';
  final months = isNe ? ne : en;
  return '${months[date.month - 1]} ${date.day}';
}

String _formatDayLabel(BuildContext context, String label) {
  if (label == 'Today') {
    return context.tr('Today', 'आज');
  }
  if (label == 'Tomorrow') {
    return context.tr('Tomorrow', 'भोलि');
  }
  final date = DateTime.tryParse(label);
  if (date == null) {
    return label;
  }
  return '${_weekdayShort(context, date)}, ${_shortDate(context, date)}';
}

String _priorityLabel(BuildContext context, String value) {
  switch (value) {
    case 'Low':
      return context.tr('Low', 'कम');
    case 'High':
      return context.tr('High', 'उच्च');
    case 'Medium':
    default:
      return context.tr('Medium', 'मध्यम');
  }
}

String _rangeLabel(BuildContext context, String value) {
  switch (value) {
    case 'Today':
      return context.tr('Today', 'आज');
    case 'This Week':
      return context.tr('This Week', 'यस हप्ता');
    case 'All':
    default:
      return context.tr('All', 'सबै');
  }
}

InputDecoration _darkInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: const Color(0xFF0B1220),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1E2A44)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.4),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF1E2A44)),
    ),
  );
}

class _PlannerBackdrop extends StatelessWidget {
  const _PlannerBackdrop();

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
          Positioned.fill(child: CustomPaint(painter: _PlannerGridPainter())),
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
            top: 180,
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

class _PlannerGridPainter extends CustomPainter {
  const _PlannerGridPainter();

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
  bool shouldRepaint(covariant _PlannerGridPainter oldDelegate) => false;
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
