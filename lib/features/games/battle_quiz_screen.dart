import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/game_zone_scaffold.dart';
import 'package:student_survivor/core/widgets/math_text.dart';
import 'package:student_survivor/data/activity_log_service.dart';
import 'package:student_survivor/data/ai_quiz_service.dart';
import 'package:student_survivor/data/quiz_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/app_models.dart';

class BattleQuizScreen extends StatefulWidget {
  final Subject subject;
  final Chapter chapter;

  const BattleQuizScreen({
    super.key,
    required this.subject,
    required this.chapter,
  });

  @override
  State<BattleQuizScreen> createState() => _BattleQuizScreenState();
}

class _BattleQuizScreenState extends State<BattleQuizScreen> {
  late final SupabaseClient _client;
  late final AiQuizService _aiQuizService;
  late final ActivityLogService _activityLogService;
  RealtimeChannel? _roomChannel;
  final _random = Random();
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _answered = false;
  int? _selectedIndex;
  String? _roomId;
  String? _roomCode;
  String? _error;
  String _status = 'waiting';
  int _targetScore = 10;
  bool _isHost = false;

  int _myScore = 0;
  int _opponentScore = 0;
  int _correctStreak = 0;
  int _lastPointsEarned = 0;
  List<_BattleQuestion> _questions = const [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _client = SupabaseConfig.client;
    _aiQuizService = AiQuizService(_client);
    _activityLogService = ActivityLogService(_client);
    _isLoading = false;
  }

  @override
  void dispose() {
    _roomChannel?.unsubscribe();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _resetLobby() {
    _roomChannel?.unsubscribe();
    _safeSetState(() {
      _error = null;
      _roomId = null;
      _roomCode = null;
      _status = 'waiting';
      _questions = const [];
      _currentIndex = 0;
      _myScore = 0;
      _opponentScore = 0;
      _correctStreak = 0;
      _lastPointsEarned = 0;
      _isHost = false;
    });
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buffer = StringBuffer();
    for (var i = 0; i < 6; i += 1) {
      buffer.write(chars[_random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  Future<String> _createUniqueRoomCode() async {
    for (var attempt = 0; attempt < 5; attempt += 1) {
      final code = _generateRoomCode();
      final existing = await _client
          .from('battle_rooms')
          .select('id')
          .eq('room_code', code)
          .limit(1);
      if ((existing as List<dynamic>).isEmpty) {
        return code;
      }
    }
    return _generateRoomCode();
  }

  Future<void> _enterRoom({
    required String roomId,
    String? roomCode,
    required bool isHost,
    required int targetScore,
  }) async {
    _roomId = roomId;
    _roomCode = roomCode;
    _isHost = isHost;
    _targetScore = targetScore;
    await _loadRoomState();
    _subscribeRoom();
    unawaited(_ensureQuestions());
    await _loadQuestions();
    await _syncProgress();
  }

  Future<void> _createRoom() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _safeSetState(() {
        _error = 'Please sign in to start a battle.';
        _isLoading = false;
      });
      return;
    }
    _safeSetState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Map<String, dynamic>? created;
      String? code;
      for (var attempt = 0; attempt < 5; attempt += 1) {
        code = await _createUniqueRoomCode();
        try {
          created = await _client
              .from('battle_rooms')
              .insert({
                'subject_id': widget.subject.id,
                'chapter_id': widget.chapter.id,
                'created_by': user.id,
                'status': 'waiting',
                'target_score': 10,
                'room_code': code,
              })
              .select('id,target_score,room_code')
              .single();
          break;
        } on PostgrestException catch (error) {
          if (error.code == '23505' && attempt < 4) {
            continue;
          }
          rethrow;
        }
      }

      if (created == null) {
        throw Exception('Failed to create a battle room.');
      }

      final roomId = created['id']?.toString();
      if (roomId == null || roomId.isEmpty) {
        throw Exception('Failed to create a battle room.');
      }

      await _client.from('battle_players').upsert({
        'room_id': roomId,
        'user_id': user.id,
      }, onConflict: 'room_id,user_id');

      await _enterRoom(
        roomId: roomId,
        roomCode: created['room_code']?.toString() ?? code,
        isHost: true,
        targetScore: (created['target_score'] as num?)?.toInt() ?? 10,
      );
    } catch (error) {
      final details = error is PostgrestException
          ? '${error.message} ${error.details ?? ''} ${error.hint ?? ''} ${error.code ?? ''}'
          : error.toString();
      _safeSetState(() {
        _error = 'Failed to create room: $details';
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _promptJoinCode() async {
    if (!mounted) return;
    final controller = TextEditingController();
    final code = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Join with code'),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Room code',
              hintText: 'e.g. 7K9P2A',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
    if (code == null || code.trim().isEmpty) {
      return;
    }
    await _joinRoom(code.trim().toUpperCase());
  }

  Future<void> _joinRoom(String code) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _safeSetState(() {
        _error = 'Please sign in to start a battle.';
        _isLoading = false;
      });
      return;
    }
    _safeSetState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final room = await _client
          .from('battle_rooms')
          .select('id,created_by,target_score,status,room_code')
          .eq('room_code', code)
          .maybeSingle();
      if (room == null) {
        throw Exception('Room code not found.');
      }
      if (room['status']?.toString() != 'waiting') {
        throw Exception('This room is not accepting players.');
      }
      final roomId = room['id']?.toString();
      if (roomId == null || roomId.isEmpty) {
        throw Exception('Invalid room.');
      }
      final players = await _client
          .from('battle_players')
          .select('id')
          .eq('room_id', roomId);
      if ((players as List<dynamic>).length >= 2) {
        throw Exception('Room is already full.');
      }

      await _client.from('battle_players').upsert({
        'room_id': roomId,
        'user_id': user.id,
      }, onConflict: 'room_id,user_id');

      await _client
          .from('battle_rooms')
          .update({'status': 'active'})
          .eq('id', roomId);

      await _enterRoom(
        roomId: roomId,
        roomCode: room['room_code']?.toString() ?? code,
        isHost: room['created_by']?.toString() == user.id,
        targetScore: (room['target_score'] as num?)?.toInt() ?? 10,
      );
    } catch (error) {
      final details = error is PostgrestException
          ? '${error.message} ${error.details ?? ''} ${error.hint ?? ''} ${error.code ?? ''}'
          : error.toString();
      _safeSetState(() {
        _error = 'Failed to join: $details';
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRoomState() async {
    final roomId = _roomId;
    if (roomId == null) return;
    final room = await _client
        .from('battle_rooms')
        .select('status,target_score')
        .eq('id', roomId)
        .maybeSingle();
    if (room != null) {
      _status = room['status']?.toString() ?? 'waiting';
      _targetScore = (room['target_score'] as num?)?.toInt() ?? 10;
    }

    final players = await _client
        .from('battle_players')
        .select('user_id,score')
        .eq('room_id', roomId);

    final user = _client.auth.currentUser;
    if (user == null) return;
    _myScore = 0;
    _opponentScore = 0;
    for (final row in players as List<dynamic>) {
      final uid = row['user_id']?.toString() ?? '';
      final score = (row['score'] as num?)?.toInt() ?? 0;
      if (uid == user.id) {
        _myScore = score;
      } else if (uid.isNotEmpty) {
        _opponentScore = score;
      }
    }
    _safeSetState(() {});
  }

  void _subscribeRoom() {
    if (_roomId == null) return;
    _roomChannel?.unsubscribe();
    _roomChannel = _client.channel('battle_room_${_roomId!}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'battle_players',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: _roomId!,
        ),
        callback: (payload) {
          _loadRoomState();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'battle_rooms',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: _roomId!,
        ),
        callback: (payload) {
          _loadRoomState();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'battle_questions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'room_id',
          value: _roomId!,
        ),
        callback: (payload) {
          _loadQuestions();
        },
      )
      ..subscribe();
  }

  Future<void> _ensureQuestions() async {
    final roomId = _roomId;
    if (!_isHost || roomId == null) return;
    _safeSetState(() {
      _isGenerating = true;
    });
    try {
      final existing = await _client
          .from('battle_questions')
          .select('id')
          .eq('room_id', roomId)
          .limit(1);
      if ((existing as List<dynamic>).isNotEmpty) {
        return;
      }
      final questions = await _generateBattleQuestions();
      if (questions.isEmpty) {
        _safeSetState(() {
          _error = 'No questions available for this chapter.';
        });
        return;
      }
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < questions.length; i += 1) {
        final q = questions[i];
        rows.add({
          'room_id': roomId,
          'prompt': q.prompt,
          'options': q.options,
          'correct_index': q.correctIndex,
          'explanation': q.explanation,
          'difficulty': q.difficulty,
          'order_index': i,
        });
      }
      await _client.from('battle_questions').insert(rows);
    } catch (error) {
      final details = error is PostgrestException
          ? '${error.message} ${error.details ?? ''} ${error.hint ?? ''} ${error.code ?? ''}'
          : error.toString();
      _safeSetState(() {
        _error = 'Failed to generate questions: $details';
      });
    } finally {
      _safeSetState(() {
        _isGenerating = false;
      });
    }
  }

  Future<List<QuizQuestionItem>> _generateBattleQuestions() async {
    try {
      final easy = await _aiQuizService
          .generateQuestions(
            quizId: 'battle_easy_${_roomId ?? 'local'}',
            subject: widget.subject,
            chapter: widget.chapter,
            count: 4,
            baseDifficulty: QuizDifficulty.easy,
          )
          .timeout(const Duration(seconds: 20));
      final medium = await _aiQuizService
          .generateQuestions(
            quizId: 'battle_medium_${_roomId ?? 'local'}',
            subject: widget.subject,
            chapter: widget.chapter,
            count: 3,
            baseDifficulty: QuizDifficulty.medium,
          )
          .timeout(const Duration(seconds: 20));
      final hard = await _aiQuizService
          .generateQuestions(
            quizId: 'battle_hard_${_roomId ?? 'local'}',
            subject: widget.subject,
            chapter: widget.chapter,
            count: 3,
            baseDifficulty: QuizDifficulty.hard,
          )
          .timeout(const Duration(seconds: 20));
      final combined = [...easy, ...medium, ...hard];
      if (combined.isNotEmpty) {
        return combined;
      }
    } catch (_) {
      // fall back below
    }

    return _fallbackQuestionsFromNotes();
  }

  List<QuizQuestionItem> _fallbackQuestionsFromNotes() {
    final notes = widget.chapter.notes
        .where((note) =>
            note.shortAnswer.trim().isNotEmpty ||
            note.detailedAnswer.trim().isNotEmpty)
        .toList();
    if (notes.isEmpty) {
      return [];
    }
    final questions = <QuizQuestionItem>[];
    for (var i = 0; i < min(notes.length, 10); i += 1) {
      final note = notes[i];
      final correct = note.shortAnswer.trim().isNotEmpty
          ? note.shortAnswer.trim()
          : note.detailedAnswer.trim();
      final options = <String>{_trimText(correct, 120)};
      while (options.length < 4 && options.length < notes.length) {
        final other = notes[_random.nextInt(notes.length)];
        final text = other.shortAnswer.trim().isNotEmpty
            ? other.shortAnswer.trim()
            : other.detailedAnswer.trim();
        if (text.isNotEmpty) {
          options.add(_trimText(text, 120));
        }
      }
      while (options.length < 4) {
        options.add('None of the above');
      }
      final optionList = options.toList()..shuffle(_random);
      final correctIndex = optionList.indexOf(_trimText(correct, 120));
      questions.add(
        QuizQuestionItem(
          id: 'fallback_${DateTime.now().millisecondsSinceEpoch}_$i',
          prompt: 'What is ${note.title}?',
          options: optionList,
          correctIndex: correctIndex == -1 ? 0 : correctIndex,
          topic: note.title,
          difficulty: i < 4
              ? 'easy'
              : i < 7
                  ? 'medium'
                  : 'hard',
          explanation: null,
        ),
      );
    }
    return questions;
  }

  Future<void> _loadQuestions() async {
    final roomId = _roomId;
    if (roomId == null) return;
    final rows = await _client
        .from('battle_questions')
        .select('id,prompt,options,correct_index,explanation,difficulty,order_index')
        .eq('room_id', roomId)
        .order('order_index');
    final questions = <_BattleQuestion>[];
    for (final row in rows as List<dynamic>) {
      final options = (row['options'] as List<dynamic>? ?? [])
          .map((option) => option.toString())
          .toList();
      questions.add(
        _BattleQuestion(
          id: row['id']?.toString() ?? '',
          prompt: row['prompt']?.toString() ?? '',
          options: options,
          correctIndex: (row['correct_index'] as num?)?.toInt() ?? 0,
          explanation: row['explanation']?.toString(),
          difficulty: row['difficulty']?.toString(),
        ),
      );
    }
    _safeSetState(() {
      _questions = questions;
    });
    await _syncProgress();
  }

  Future<void> _syncProgress() async {
    final user = _client.auth.currentUser;
    final roomId = _roomId;
    if (user == null || roomId == null) return;
    final answers = await _client
        .from('battle_answers')
        .select('question_id,is_correct')
        .eq('room_id', roomId)
        .eq('user_id', user.id);

    final answeredCount = (answers as List<dynamic>).length;
    _safeSetState(() {
      if (_questions.isEmpty) {
        _currentIndex = 0;
      } else {
        _currentIndex = min(answeredCount, _questions.length - 1);
      }
      _answered = false;
      _selectedIndex = null;
    });
  }

  String _trimText(String text, int max) {
    if (text.length <= max) {
      return text;
    }
    return text.substring(0, max);
  }

  Future<void> _selectAnswer(int index) async {
    if (_answered) return;
    final roomId = _roomId;
    if (roomId == null) return;
    final question = _currentQuestion;
    if (question == null) return;
    final user = _client.auth.currentUser;
    if (user == null) return;
    final isCorrect = index == question.correctIndex;
    final points = isCorrect
        ? _calculateBattlePoints(
            difficulty: question.difficulty,
            currentStreak: _correctStreak + 1,
            myScore: _myScore,
            opponentScore: _opponentScore,
          )
        : 0;

    _safeSetState(() {
      _selectedIndex = index;
      _answered = true;
      _lastPointsEarned = points;
      if (isCorrect) {
        _correctStreak += 1;
        _myScore += points;
      } else {
        _correctStreak = 0;
      }
    });
    _activityLogService.logActivityUnawaited(
      type: 'battle_answer',
      source: 'battle_quiz',
      points: points,
      subjectId: widget.subject.id,
      chapterId: widget.chapter.id,
      metadata: {
        'correct': isCorrect,
        'streak': _correctStreak,
        'difficulty': question.difficulty,
      },
    );

    try {
      await _client.from('battle_answers').insert({
        'room_id': roomId,
        'question_id': question.id,
        'user_id': user.id,
        'selected_index': index,
        'is_correct': isCorrect,
      });

      if (isCorrect) {
        await _client
            .from('battle_players')
            .update({'score': _myScore})
            .eq('room_id', roomId)
            .eq('user_id', user.id);
      }

      if (_myScore >= _targetScore || _opponentScore >= _targetScore) {
        await _client
            .from('battle_rooms')
            .update({'status': 'finished'})
            .eq('id', roomId);
      }
    } catch (error) {
      _safeSetState(() {
        _error = 'Failed to submit answer: $error';
      });
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      _safeSetState(() {
        _currentIndex += 1;
        _answered = false;
        _selectedIndex = null;
        _lastPointsEarned = 0;
      });
    }
  }

  int _calculateBattlePoints({
    required String? difficulty,
    required int currentStreak,
    required int myScore,
    required int opponentScore,
  }) {
    final base = _basePointsForDifficulty(difficulty);
    final streakBonus = _streakBonus(currentStreak);
    final comebackBonus = (opponentScore - myScore) >= 3 ? 1 : 0;
    return base + streakBonus + comebackBonus;
  }

  int _basePointsForDifficulty(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'hard':
        return 3;
      case 'medium':
        return 2;
      case 'easy':
        return 1;
      default:
        return 2;
    }
  }

  int _streakBonus(int streak) {
    if (streak >= 8) {
      return 3;
    }
    if (streak >= 5) {
      return 2;
    }
    if (streak >= 3) {
      return 1;
    }
    return 0;
  }

  _BattleQuestion? get _currentQuestion {
    if (_questions.isEmpty || _currentIndex >= _questions.length) {
      return null;
    }
    return _questions[_currentIndex];
  }

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    final ready = _status == 'active' && question != null;
    final finished = _status == 'finished';
    final appBar = AppBar(
      title: Text(
        'Battle Quiz (2P)',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    );
    final body = Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + kToolbarHeight + 12,
        20,
        28,
      ),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _arenaAccent),
            )
          : _error != null
              ? _BattleError(message: _error!, onRetry: _resetLobby)
              : _roomId == null
                  ? _BattleLobby(
                      onCreate: _createRoom,
                      onJoin: _promptJoinCode,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      _BattleHeader(
                        status: _status,
                        targetScore: _targetScore,
                        myScore: _myScore,
                        opponentScore: _opponentScore,
                        difficulty: question?.difficulty?.toUpperCase() ?? '-',
                        isHost: _isHost,
                        isGenerating: _isGenerating,
                      ),
                      const SizedBox(height: 16),
                      if (_status == 'waiting')
                        _WaitingCard(
                          roomCode: _roomCode,
                          onCopy: _roomCode == null
                              ? null
                              : () {
                                  Clipboard.setData(
                                    ClipboardData(text: _roomCode!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Room code copied'),
                                    ),
                                  );
                                },
                          onCancel: () => Navigator.of(context).pop(),
                        ),
                      if (_status == 'active' && question == null)
                        _ArenaCard(
                          child: Column(
                            children: [
                              const Icon(Icons.hourglass_empty,
                                  size: 48, color: _arenaMuted),
                              const SizedBox(height: 12),
                              Text(
                                'Preparing questions...',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please wait a moment.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: _arenaMuted),
                              ),
                            ],
                          ),
                        ),
                      if (ready)
                        Expanded(
                          child: _ArenaCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MathText(
                                  text: question.prompt,
                                  textStyle: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: question.options.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final option = question.options[index];
                                      final isSelected =
                                          _selectedIndex == index;
                                      final isCorrect =
                                          question.correctIndex == index;
                                      final showCorrect = _answered && isCorrect;
                                      final showWrong =
                                          _answered && isSelected && !isCorrect;
                                      Color? borderColor;
                                      if (showCorrect) {
                                        borderColor = AppColors.success;
                                      } else if (showWrong) {
                                        borderColor = AppColors.danger;
                                      }
                                      return OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          alignment: Alignment.centerLeft,
                                          side: BorderSide(
                                            color: borderColor ??
                                                _arenaBorder,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: _answered
                                            ? null
                                            : () => _selectAnswer(index),
                                        child: MathText(
                                          text: option,
                                          textStyle: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(color: Colors.white),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                if (_answered) ...[
                                  const SizedBox(height: 12),
                                  MathText(
                                    text: _selectedIndex == question.correctIndex
                                        ? 'Correct! +$_lastPointsEarned battle points.'
                                        : 'Wrong! 0 points.',
                                    textStyle: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: _selectedIndex ==
                                                  question.correctIndex
                                              ? AppColors.success
                                              : AppColors.danger,
                                        ),
                                  ),
                                  if ((question.explanation ?? '').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: MathText(
                                        text: question.explanation!,
                                        textStyle: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: _arenaMuted),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _nextQuestion,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _arenaAccent,
                                        foregroundColor:
                                            const Color(0xFF0B1220),
                                      ),
                                      child: const Text('Next'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      if (finished)
                        _BattleFinishedCard(
                          myScore: _myScore,
                          opponentScore: _opponentScore,
                          targetScore: _targetScore,
                          onExit: () => Navigator.of(context).pop(),
                        ),
                    ],
                  ),
    );
    return GameZoneScaffold(
      appBar: appBar,
      body: body,
      useSafeArea: false,
      extendBodyBehindAppBar: true,
    );
  }
}

class _BattleQuestion {
  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? explanation;
  final String? difficulty;

  const _BattleQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanation,
    this.difficulty,
  });
}

class _BattleHeader extends StatelessWidget {
  final String status;
  final int targetScore;
  final int myScore;
  final int opponentScore;
  final String difficulty;
  final bool isHost;
  final bool isGenerating;

  const _BattleHeader({
    required this.status,
    required this.targetScore,
    required this.myScore,
    required this.opponentScore,
    required this.difficulty,
    required this.isHost,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = status == 'waiting' ? 'Waiting for opponent' : 'Battle On';
    return _ArenaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$statusText • Target $targetScore pts',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ScorePill(label: 'You', score: myScore),
              const SizedBox(width: 12),
              _ScorePill(label: 'Opponent', score: opponentScore),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Difficulty: $difficulty',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: _arenaMuted),
              ),
              if (isHost && isGenerating) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final int score;

  const _ScorePill({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _arenaSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _arenaBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _arenaMuted),
            ),
            const SizedBox(height: 4),
            Text(
              score.toString(),
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
    );
  }
}

class _BattleLobby extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  const _BattleLobby({
    required this.onCreate,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _ArenaCard(
        child: Column(
          children: [
            const Icon(Icons.videogame_asset,
                size: 48, color: _arenaMuted),
            const SizedBox(height: 12),
            Text(
              'Battle Quiz (2P)',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a room and share the code, or join with a code.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _arenaMuted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onCreate,
              style: _arenaPrimaryButtonStyle(),
              child: const Text('Create Room'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: onJoin,
              style: _arenaTonalButtonStyle(),
              child: const Text('Join with Code'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  final String? roomCode;
  final VoidCallback? onCopy;
  final VoidCallback onCancel;

  const _WaitingCard({
    required this.roomCode,
    required this.onCopy,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _ArenaCard(
      child: Column(
        children: [
          const Icon(Icons.groups, size: 48, color: _arenaMuted),
          const SizedBox(height: 12),
          Text(
            'Waiting for opponent...',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Share the room code with your friend to start.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: _arenaMuted),
          ),
          if (roomCode != null) ...[
            const SizedBox(height: 16),
            Text(
              'Room Code',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _arenaMuted),
            ),
            const SizedBox(height: 4),
            Text(
              roomCode!,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: onCopy,
              style: _arenaTonalButtonStyle(),
              child: const Text('Copy Code'),
            ),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(foregroundColor: _arenaAccent),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _BattleFinishedCard extends StatelessWidget {
  final int myScore;
  final int opponentScore;
  final int targetScore;
  final VoidCallback onExit;

  const _BattleFinishedCard({
    required this.myScore,
    required this.opponentScore,
    required this.targetScore,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final won = myScore >= targetScore && myScore > opponentScore;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _ArenaCard(
        child: Column(
          children: [
            Text(
              won ? 'You Win!' : 'Battle Finished',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your score: $myScore • Opponent: $opponentScore',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: _arenaMuted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onExit,
                style: _arenaTonalButtonStyle(),
                child: const Text('Exit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BattleError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _BattleError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bolt, size: 48, color: _arenaMuted),
          const SizedBox(height: 12),
          Text(
            'Battle paused',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: _arenaMuted),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: _arenaPrimaryButtonStyle(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

const _arenaSurface = Color(0xFF0B1220);
const _arenaBorder = Color(0xFF1E2A44);
const _arenaMuted = Color(0xFF94A3B8);
const _arenaAccent = Color(0xFF38BDF8);

ButtonStyle _arenaPrimaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: _arenaAccent,
    foregroundColor: const Color(0xFF0B1220),
  );
}

ButtonStyle _arenaTonalButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: const Color(0xFF111B2E),
    foregroundColor: Colors.white,
  );
}

class _ArenaCard extends StatelessWidget {
  final Widget child;

  const _ArenaCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _arenaSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _arenaBorder),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: child,
      ),
    );
  }
}
