import 'dart:async' as async;
import 'dart:convert';
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/data/activity_log_service.dart';
import 'package:student_survivor/data/ai_quiz_service.dart';
import 'package:student_survivor/data/quiz_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/app_models.dart';

enum RewardType { medkit, shield, weapon, coins, bomb, power }

class SurvivalGameSave {
  final int level;
  final int kills;
  final int coins;
  final double health;
  final double shield;
  final int weaponLevel;
  final double playerX;
  final double playerY;
  final int savedAt;

  const SurvivalGameSave({
    required this.level,
    required this.kills,
    required this.coins,
    required this.health,
    required this.shield,
    required this.weaponLevel,
    required this.playerX,
    required this.playerY,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'level': level,
        'kills': kills,
        'coins': coins,
        'health': health,
        'shield': shield,
        'weaponLevel': weaponLevel,
        'playerX': playerX,
        'playerY': playerY,
        'savedAt': savedAt,
      };

  factory SurvivalGameSave.fromJson(Map<String, dynamic> json) {
    return SurvivalGameSave(
      level: (json['level'] ?? 1) as int,
      kills: (json['kills'] ?? 0) as int,
      coins: (json['coins'] ?? 0) as int,
      health: (json['health'] ?? 100).toDouble(),
      shield: (json['shield'] ?? 0).toDouble(),
      weaponLevel: (json['weaponLevel'] ?? 1) as int,
      playerX: (json['playerX'] ?? 0).toDouble(),
      playerY: (json['playerY'] ?? 0).toDouble(),
      savedAt: (json['savedAt'] ?? 0) as int,
    );
  }
}

class SurvivalQuizGameScreen extends StatefulWidget {
  final Subject subject;
  final Chapter chapter;

  const SurvivalQuizGameScreen({
    super.key,
    required this.subject,
    required this.chapter,
  });

  @override
  State<SurvivalQuizGameScreen> createState() => _SurvivalQuizGameScreenState();
}

class _SurvivalQuizGameScreenState extends State<SurvivalQuizGameScreen>
    with SingleTickerProviderStateMixin {
  static const _prefSound = 'survival_sound_enabled';
  static const _prefVibration = 'survival_vibration_enabled';
  static const _prefSave = 'survival_game_save';
  static const _soundShoot = 'sounds/shoot.wav';
  static const _soundHit = 'sounds/hit.wav';
  static const _soundReward = 'sounds/reward.wav';
  static const _soundUi = 'sounds/ui.wav';
  static const _soundBossLoop = 'sounds/boss_loop.wav';

  late final SurvivalQuizGame _game;
  late final GameWidget _gameWidget;
  late final AiQuizService _aiQuizService;
  late final ActivityLogService _activityLogService;

  bool _showQuiz = false;
  bool _isLoadingQuestion = false;
  String? _quizError;
  QuizQuestionItem? _question;
  String? _hint;
  String? _correctAnswer;
  String? _answerExplanation;
  String? _lastQuestionKey;
  final Set<String> _askedQuestionKeys = {};
  List<QuizQuestionItem> _quizQuestions = const [];
  int _quizIndex = 0;
  int _quizCorrect = 0;
  String? _lastWrongSelected;
  String? _lastWrongAnswer;
  String? _lastWrongExplanation;
  String? _lastWrongPrompt;
  static const int _quizTotal = 5;
  static const int _quizPass = 3;
  final Random _random = Random();
  static const int _resumeCost = 20;
  bool _showSettings = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  SurvivalGameSave? _savedGame;
  async.Timer? _autoSaveTimer;
  bool _audioReady = false;
  bool _audioFailed = false;
  bool _audioNoticeShown = false;
  bool _bossAlive = false;

  int _level = 1;
  int _kills = 0;
  int _coins = 0;
  double _health = 100;
  double _shield = 0;
  int _weaponLevel = 1;
  bool _gameOver = false;
  bool _playerHidden = false;
  double _powerSeconds = 0;
  String? _rewardMessage;
  AnimationController? _horrorPulse;

  int _waveTargetForLevel(int level) {
    return 5 + max(0, level - 1) * 2;
  }
  async.Timer? _rewardTimer;
  String? _stageIntro;
  async.Timer? _stageIntroTimer;

  @override
  void initState() {
    super.initState();
    _horrorPulse ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _aiQuizService = AiQuizService(SupabaseConfig.client);
    _activityLogService = ActivityLogService(SupabaseConfig.client);
    _loadLocalSettings();
    _primeAudio();
    _game = SurvivalQuizGame(
      onQuizTrigger: _handleQuizTrigger,
      onKillsChanged: (value) => _setStateSafe(() => _kills = value),
      onHealthChanged: (value) => _setStateSafe(() => _health = value),
      onShieldChanged: (value) => _setStateSafe(() => _shield = value),
      onWeaponChanged: (value) => _setStateSafe(() => _weaponLevel = value),
      onCoinsChanged: (value) => _setStateSafe(() => _coins = value),
      onGameOver: _handleGameOver,
      onPlayerHit: _handlePlayerHit,
      onBossStateChanged: _handleBossStateChanged,
      onHiddenChanged: (value) => _setStateSafe(() => _playerHidden = value),
      onPickupReward: _showReward,
      onPowerChanged: (value) => _setStateSafe(() => _powerSeconds = value),
    );
    _gameWidget = GameWidget(game: _game);
    _game.pauseEngine();
    _autoSaveTimer = async.Timer.periodic(
      const Duration(seconds: 5),
      (_) => _persistGameState(),
    );
  }

  void _setStateSafe(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || phase == SchedulerPhase.postFrameCallbacks) {
      setState(fn);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(fn);
      });
    }
  }

  @override
  void dispose() {
    _horrorPulse?.dispose();
    _game.dispose();
    _autoSaveTimer?.cancel();
    _persistGameState();
    _stopBossMusic();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _loadLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saveJson = prefs.getString(_prefSave);
      SurvivalGameSave? save;
      if (saveJson != null) {
        try {
          final decoded = jsonDecode(saveJson) as Map<String, dynamic>;
          save = SurvivalGameSave.fromJson(decoded);
        } catch (_) {
          save = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _soundEnabled = prefs.getBool(_prefSound) ?? true;
        _vibrationEnabled = prefs.getBool(_prefVibration) ?? true;
        _savedGame = save;
      });
    } catch (_) {
      // Ignore prefs failures for now.
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefSound, _soundEnabled);
      await prefs.setBool(_prefVibration, _vibrationEnabled);
    } catch (_) {}
  }

  Future<void> _primeAudio() async {
    try {
      FlameAudio.audioCache.prefix = 'assets/';
      await FlameAudio.audioCache.loadAll(const [
        _soundShoot,
        _soundHit,
        _soundReward,
        _soundUi,
        _soundBossLoop,
      ]);
      _audioReady = true;
    } catch (_) {
      _audioReady = false;
      _audioFailed = true;
    }
  }

  Future<void> _playSound(String asset, {double volume = 1.0}) async {
    if (!_soundEnabled || _audioFailed) return;
    try {
      if (!_audioReady) {
        await _primeAudio();
      }
      await FlameAudio.play(asset, volume: volume);
    } on MissingPluginException {
      _audioFailed = true;
      _setStateSafe(() => _soundEnabled = false);
      _showAudioUnavailable();
    } catch (_) {
      _audioFailed = true;
      _setStateSafe(() => _soundEnabled = false);
      _showAudioUnavailable();
    }
  }

  Future<void> _startBossMusic() async {
    if (!_soundEnabled || _audioFailed) return;
    try {
      await FlameAudio.bgm.play(_soundBossLoop, volume: 0.35);
    } catch (_) {
      _audioFailed = true;
      _setStateSafe(() => _soundEnabled = false);
      _showAudioUnavailable();
    }
  }

  Future<void> _stopBossMusic() async {
    try {
      await FlameAudio.bgm.stop();
    } catch (_) {}
  }

  void _showAudioUnavailable() {
    if (_audioNoticeShown) return;
    _audioNoticeShown = true;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sound is not available on this device.')),
    );
  }

  Future<void> _persistGameState({bool force = false}) async {
    if (!force) {
      if (_gameOver) return;
      if (_showSettings) return;
    }
    final save = SurvivalGameSave(
      level: _level,
      kills: _kills,
      coins: _coins,
      health: _health,
      shield: _shield,
      weaponLevel: _weaponLevel,
      playerX: _game.playerPosition.x,
      playerY: _game.playerPosition.y,
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefSave, jsonEncode(save.toJson()));
      if (!mounted) return;
      setState(() {
        _savedGame = save;
      });
    } catch (_) {}
  }

  Future<void> _clearSavedGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefSave);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _savedGame = null;
    });
  }

  void _startNewGame() {
    _clearSavedGame();
    setState(() {
      _gameOver = false;
      _showQuiz = false;
      _question = null;
      _quizQuestions = const [];
      _quizIndex = 0;
      _quizCorrect = 0;
      _lastWrongSelected = null;
      _lastWrongAnswer = null;
      _lastWrongExplanation = null;
      _lastWrongPrompt = null;
      _hint = null;
      _quizError = null;
      _rewardMessage = null;
      _showSettings = false;
      _level = 1;
      _kills = 0;
      _coins = 0;
      _health = 100;
      _shield = 0;
      _weaponLevel = 1;
      _powerSeconds = 0;
      _lastQuestionKey = null;
      _askedQuestionKeys.clear();
    });
    _game.reset();
    _playSound(_soundUi, volume: 0.5);
    _game.resumeEngine();
  }

  void _resumeFromSave() {
    final save = _savedGame;
    if (save == null) return;
    setState(() {
      _showSettings = false;
      _gameOver = false;
      _showQuiz = false;
      _question = null;
      _quizQuestions = const [];
      _quizIndex = 0;
      _quizCorrect = 0;
      _lastWrongSelected = null;
      _lastWrongAnswer = null;
      _lastWrongExplanation = null;
      _lastWrongPrompt = null;
      _hint = null;
      _quizError = null;
      _rewardMessage = null;
      _level = save.level;
      _kills = save.kills;
      _coins = save.coins;
    _health = save.health;
    _shield = save.shield;
    _weaponLevel = save.weaponLevel;
    _powerSeconds = 0;
    });
    _game.restoreFromSave(save);
    _playSound(_soundUi, volume: 0.5);
  }

  Future<void> _handleQuizTrigger() async {
    _setStateSafe(() {
      _showQuiz = true;
      _isLoadingQuestion = true;
      _quizError = null;
      _question = null;
      _quizQuestions = const [];
      _quizIndex = 0;
      _quizCorrect = 0;
      _lastWrongSelected = null;
      _lastWrongAnswer = null;
      _lastWrongExplanation = null;
      _lastWrongPrompt = null;
      _hint = null;
      _correctAnswer = null;
      _answerExplanation = null;
    });
    _playSound(_soundUi, volume: 0.4);
    try {
      final difficulty = _level <= 1
          ? QuizDifficulty.easy
          : _level == 2
              ? QuizDifficulty.medium
              : QuizDifficulty.hard;
      final nonce =
          '${DateTime.now().millisecondsSinceEpoch}-$_level-$_kills-${_askedQuestionKeys.length}';
      final questions = await _aiQuizService.generateQuestions(
        quizId:
            'survival_${widget.chapter.id}_${_level}_${DateTime.now().millisecondsSinceEpoch}',
        subject: widget.subject,
        chapter: widget.chapter,
        count: _quizTotal + 2,
        baseDifficulty: difficulty,
        nonce: nonce,
      );
      if (questions.isEmpty) {
        throw Exception('No questions available.');
      }
      final pool = List<QuizQuestionItem>.from(questions)..shuffle(_random);
      final selected = <QuizQuestionItem>[];
      final usedKeys = <String>{};
      for (final candidate in pool) {
        if (selected.length >= _quizTotal) break;
        final key = _questionKey(candidate);
        if (key == _lastQuestionKey) {
          continue;
        }
        if (_askedQuestionKeys.contains(key)) {
          continue;
        }
        if (usedKeys.contains(key)) {
          continue;
        }
        usedKeys.add(key);
        selected.add(candidate);
      }
      if (selected.length < _quizTotal) {
        for (final candidate in pool) {
          if (selected.length >= _quizTotal) break;
          final key = _questionKey(candidate);
          if (key == _lastQuestionKey) {
            continue;
          }
          if (usedKeys.contains(key)) {
            continue;
          }
          usedKeys.add(key);
          selected.add(candidate);
        }
      }
      if (selected.length < _quizTotal) {
        throw Exception('Not enough questions available.');
      }
      final shuffledQuestions =
          selected.map(_shuffleQuestionOptions).toList();
      final first = shuffledQuestions.first;
      for (final question in shuffledQuestions) {
        _askedQuestionKeys.add(_questionKey(question));
      }
      _setStateSafe(() {
        _quizQuestions = shuffledQuestions;
        _quizIndex = 0;
        _question = first;
        _lastQuestionKey = _questionKey(first);
        _isLoadingQuestion = false;
      });
    } catch (error) {
      _setStateSafe(() {
        _quizError = 'Failed to load question: $error';
        _isLoadingQuestion = false;
      });
    }
  }

  String _questionKey(QuizQuestionItem question) {
    final normalized = question.prompt
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    return normalized;
  }

  QuizQuestionItem _shuffleQuestionOptions(QuizQuestionItem question) {
    if (question.options.length <= 1) {
      return question;
    }
    final indices = List<int>.generate(question.options.length, (i) => i);
    indices.shuffle(_random);
    final options = indices.map((i) => question.options[i]).toList();
    final correctIndex = indices.indexOf(question.correctIndex);
    return QuizQuestionItem(
      id: question.id,
      prompt: question.prompt,
      options: options,
      correctIndex: correctIndex,
      topic: question.topic,
      difficulty: question.difficulty,
      explanation: question.explanation,
    );
  }

  void _handleAnswer(int index) {
    final question = _question;
    if (question == null) return;
    final isCorrect = index == question.correctIndex;
    if (isCorrect) {
      _activityLogService.logActivityUnawaited(
        type: 'survival_quiz_correct',
        source: 'survival_quiz',
        points: 10,
        subjectId: widget.subject.id,
        chapterId: widget.chapter.id,
        metadata: {
          'level': _level,
          'kills': _kills,
          'prompt': question.prompt,
        },
      );
      _quizCorrect += 1;
    } else {
      _activityLogService.logActivityUnawaited(
        type: 'survival_quiz_wrong',
        source: 'survival_quiz',
        points: 0,
        subjectId: widget.subject.id,
        chapterId: widget.chapter.id,
        metadata: {
          'level': _level,
          'kills': _kills,
          'prompt': question.prompt,
        },
      );
      final correct = question.options[question.correctIndex];
      final explanation = (question.explanation ?? '').trim().isNotEmpty
          ? question.explanation!.trim()
          : 'Review the chapter notes to understand this concept.';
      _lastWrongSelected = question.options[index];
      _lastWrongAnswer = correct;
      _lastWrongExplanation = explanation;
      _lastWrongPrompt = question.prompt;
    }
    final isLast = _quizIndex >= _quizQuestions.length - 1;
    if (!isLast) {
      _setStateSafe(() {
        _quizIndex += 1;
        _question = _quizQuestions[_quizIndex];
        _hint = null;
      });
      return;
    }
    if (_quizCorrect >= _quizPass) {
      _setStateSafe(() {
      _showQuiz = false;
      _question = null;
      _quizQuestions = const [];
      _quizIndex = 0;
      _quizCorrect = 0;
      _lastWrongSelected = null;
      _lastWrongAnswer = null;
      _lastWrongExplanation = null;
      _lastWrongPrompt = null;
      _hint = null;
      _quizError = null;
    });
      _applyReward();
      _advanceLevel();
      _game.resumeAfterQuiz();
      _persistGameState(force: true);
      return;
    }
    _setStateSafe(() {
      _showQuiz = false;
      _question = null;
      _quizQuestions = const [];
      _quizIndex = 0;
      _quizCorrect = 0;
      _hint = null;
      _quizError = null;
      _correctAnswer = _lastWrongAnswer;
      _answerExplanation = _lastWrongExplanation;
      _gameOver = true;
    });
    _game.pauseEngine();
    _persistGameState(force: true);
  }

  void _applyReward() {
    final reward = _pickReward();
    switch (reward) {
      case RewardType.medkit:
        _game.addHealth(25);
        _showReward('+25 Health');
        _playSound(_soundReward, volume: 0.7);
        break;
      case RewardType.shield:
        _game.addShield(20);
        _showReward('+20 Shield');
        _playSound(_soundReward, volume: 0.7);
        break;
      case RewardType.weapon:
        _game.upgradeWeapon();
        _showReward('Weapon upgraded');
        _playSound(_soundReward, volume: 0.7);
        break;
      case RewardType.coins:
        _game.addCoins(20);
        _showReward('+20 Coins');
        _playSound(_soundReward, volume: 0.7);
        break;
      case RewardType.bomb:
        _game.clearZombies();
        _showReward('Bomb cleared zombies');
        _playSound(_soundReward, volume: 0.7);
        break;
      case RewardType.power:
        _game.addPowerBullets();
        _showReward('Power bullets');
        _playSound(_soundReward, volume: 0.7);
        break;
    }
  }

  RewardType _pickReward() {
    final roll = Random().nextInt(100);
    if (_level % 3 == 0) {
      if (roll < 30) return RewardType.weapon;
      if (roll < 60) return RewardType.shield;
      if (roll < 85) return RewardType.coins;
      if (roll < 95) return RewardType.power;
      return RewardType.medkit;
    }
    if (roll < 25) return RewardType.medkit;
    if (roll < 45) return RewardType.shield;
    if (roll < 60) return RewardType.weapon;
    if (roll < 80) return RewardType.coins;
    if (roll < 90) return RewardType.power;
    return RewardType.bomb;
  }

  void _showReward(String message) {
    _rewardTimer?.cancel();
    setState(() {
      _rewardMessage = message;
    });
    _rewardTimer = async.Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _rewardMessage = null;
      });
    });
  }

  void _showStageIntro(int stage) {
    _stageIntroTimer?.cancel();
    setState(() {
      _stageIntro = 'Stage $stage';
    });
    _stageIntroTimer = async.Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _stageIntro = null;
      });
    });
  }

  void _advanceLevel() {
    final previousStage = _stageForLevel(_level);
    setState(() {
      _level += 1;
      _showQuiz = false;
      _question = null;
      _hint = null;
      _quizError = null;
    });
    final newStage = _stageForLevel(_level);
    if (newStage != previousStage) {
      _showReward('Stage $newStage');
      _showStageIntro(newStage);
    }
    _game.nextLevel(_level);
  }

  void _handleGameOver() {
    _setStateSafe(() {
      _gameOver = true;
      _showQuiz = false;
    });
    _persistGameState(force: true);
  }

  int _stageForLevel(int level) {
    return ((level - 1) ~/ 3) + 1;
  }

  void _handlePlayerHit() {
    if (_vibrationEnabled) {
      HapticFeedback.lightImpact();
    }
    _playSound(_soundHit, volume: 0.6);
  }

  void _handleBossStateChanged(bool alive) {
    _bossAlive = alive;
    if (!alive) {
      _stopBossMusic();
      return;
    }
    _startBossMusic();
  }

  void _handleFire() {
    if (_showQuiz || _gameOver || _showSettings) return;
    _playSound(_soundShoot, volume: 0.5);
    _game.attack();
  }

  void _resumeAfterWrong() {
    final success = _game.spendCoins(_resumeCost);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins to continue.')),
      );
      return;
    }
    _setStateSafe(() {
      _gameOver = false;
      _correctAnswer = null;
      _answerExplanation = null;
    });
    _game.resumeAfterQuiz();
    _persistGameState(force: true);
  }

  void _resumeAfterDeath() {
    final success = _game.spendCoins(_resumeCost);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins to continue.')),
      );
      return;
    }
    _setStateSafe(() {
      _gameOver = false;
      _correctAnswer = null;
      _answerExplanation = null;
    });
    _game.clearZombies();
    _game.revive(health: 60, shield: 10);
    _showReward('Second chance!');
    _game.resumeEngine();
    _persistGameState(force: true);
  }

  Future<void> _confirmQuit() async {
    if (!mounted) return;
    final wasPaused = _game.paused;
    _game.pauseEngine();
    final shouldQuit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit game?'),
        content: const Text('Your current run will be saved and you can resume later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    if (shouldQuit == true) {
      await _quitGame();
      return;
    }
    if (!wasPaused && !_showQuiz && !_gameOver && !_showSettings) {
      _game.resumeEngine();
    }
  }

  Future<void> _quitGame() async {
    await _persistGameState();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(child: _gameWidget),
          Positioned.fill(
            child: IgnorePointer(
              child: _HorrorVignette(
                pulse: _horrorPulse ?? const AlwaysStoppedAnimation(0.0),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: SafeArea(
              bottom: false,
              child: _VitalsPill(
                health: _health,
                shield: _shield,
                hidden: _playerHidden,
                powerSeconds: _powerSeconds,
              ),
            ),
          ),
          Positioned(
            top: 74,
            left: 10,
            child: SafeArea(
              bottom: false,
              child: _QuitPill(
                onPressed: _confirmQuit,
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: SafeArea(
              bottom: false,
              child: _ScorePill(
                level: _level,
                stage: _stageForLevel(_level),
                kills: _kills,
                killsTarget: _waveTargetForLevel(_level),
                coins: _coins,
                weaponLevel: _weaponLevel,
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 20,
            child: _FireButton(
              pulse: _horrorPulse,
              onPressed:
                  _showQuiz || _gameOver || _showSettings ? null : _handleFire,
            ),
          ),
          if (_showQuiz) _buildQuizOverlay(context),
          if (_gameOver) _buildGameOver(context),
          if (_showSettings) _buildSettingsOverlay(context),
          if (_rewardMessage != null)
            Positioned(
              top: 96,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0F0E).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    _rewardMessage!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          if (_stageIntro != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _stageIntro == null ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B0F0E).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _stageIntro ?? '',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuizOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          width: 360,
          constraints: const BoxConstraints(maxHeight: 300),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0B1110),
                const Color(0xFF141012),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.danger.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: _isLoadingQuestion
              ? const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _quizError != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _quizError!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.danger),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _showQuiz = false;
                                    _question = null;
                                    _quizQuestions = const [];
                                    _quizIndex = 0;
                                    _quizCorrect = 0;
                                    _lastWrongSelected = null;
                                    _lastWrongAnswer = null;
                                    _lastWrongExplanation = null;
                                    _lastWrongPrompt = null;
                                    _hint = null;
                                    _quizError = null;
                                  });
                                  _game.resumeAfterQuiz();
                                },
                                child: const Text('Skip'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _handleQuizTrigger,
                                child: const Text('Retry'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : _question == null
                      ? const SizedBox.shrink()
                      : Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Quiz Check',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.bolt,
                                  size: 18,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Level $_level',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: AppColors.mutedInk),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Q ${_quizIndex + 1}/${_quizQuestions.isEmpty ? _quizTotal : _quizQuestions.length}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: AppColors.mutedInk),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Correct $_quizCorrect',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: AppColors.mutedInk),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Flexible(
                              fit: FlexFit.loose,
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.outline
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        _question!.prompt,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    ..._question!.options.asMap().entries.map(
                                          (entry) => Padding(
                                            padding:
                                                const EdgeInsets.only(bottom: 8),
                                            child: SizedBox(
                                              width: double.infinity,
                                              child: _QuizOptionTile(
                                                onPressed: () =>
                                                    _handleAnswer(entry.key),
                                                label: entry.value,
                                              ),
                                            ),
                                          ),
                                        ),
                                    if (_hint != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.lightbulb,
                                              size: 18,
                                              color: AppColors.accent,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _hint!,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: AppColors.mutedInk,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
        ),
      ),
    );
  }

  Widget _buildSettingsOverlay(BuildContext context) {
    final hasSave = _savedGame != null;
    final maxWidth = min(440.0, MediaQuery.of(context).size.width - 40);
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF08130C),
                  Colors.black.withValues(alpha: 0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        const Positioned(
          top: -80,
          left: -60,
          child: _BackdropGlow(
            color: AppColors.secondary,
            size: 220,
          ),
        ),
        const Positioned(
          bottom: -90,
          right: -40,
          child: _BackdropGlow(
            color: AppColors.accent,
            size: 260,
          ),
        ),
        Center(
          child: Container(
            width: maxWidth,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surface,
                  AppColors.surface.withValues(alpha: 0.92),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.outline.withValues(alpha: 0.7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.78,
              ),
              child: SingleChildScrollView(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            const _ZombieBackdrop(),
                            Container(
                              color: Colors.black.withValues(alpha: 0.55),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.secondary.withValues(alpha: 0.3),
                                        AppColors.accent.withValues(alpha: 0.22),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            AppColors.secondary.withValues(alpha: 0.25),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.shield, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Study Survivor',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Zombie waves • Quiz checkpoints • Boss fights',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: AppColors.mutedInk),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: const [
                                          _HudChip(label: 'Wave system'),
                                          _HudChip(label: '5 Q check'),
                                          _HudChip(label: 'Pass 3'),
                                          _HudChip(label: 'Resume 20 coins'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _MiniInfo(
                                    icon: Icons.gamepad_outlined,
                                    label: 'Move',
                                    value: 'Joystick',
                                  ),
                                  const SizedBox(width: 10),
                                  _MiniInfo(
                                    icon: Icons.flash_on,
                                    label: 'Fire',
                                    value: 'Tap',
                                  ),
                                  const SizedBox(width: 10),
                                  _MiniInfo(
                                    icon: Icons.timer_outlined,
                                    label: 'Waves',
                                    value: 'Clear all',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.paper.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.outline),
                              ),
                              child: Column(
                                children: [
                                  _SettingRow(
                                    icon: Icons.volume_up_rounded,
                                    title: 'Sound',
                                    subtitle: 'Enable in-game effects',
                                    value: _soundEnabled,
                                    onChanged: (value) {
                                      setState(() => _soundEnabled = value);
                                      _saveSettings();
                                      if (value) {
                                        _primeAudio();
                                        _playSound(_soundUi, volume: 0.4);
                                        if (_bossAlive) {
                                          _startBossMusic();
                                        }
                                      } else {
                                        _stopBossMusic();
                                      }
                                    },
                                  ),
                                  const Divider(height: 16),
                                  _SettingRow(
                                    icon: Icons.vibration_rounded,
                                    title: 'Vibration',
                                    subtitle: 'Haptic feedback on hits',
                                    value: _vibrationEnabled,
                                    onChanged: (value) {
                                      setState(() => _vibrationEnabled = value);
                                      _saveSettings();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            if (hasSave) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color:
                                        AppColors.secondary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.restore_rounded),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Saved run • Wave ${_savedGame!.level} • '
                                        'K ${_savedGame!.kills} • \$ ${_savedGame!.coins}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _confirmQuit,
                                    child: const Text('Quit'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _startNewGame,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.secondary,
                                      foregroundColor: Colors.white,
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text('Start Run'),
                                  ),
                                ),
                                if (hasSave) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _resumeFromSave,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.accent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                      ),
                                      child: const Text('Resume'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameOver(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 340,
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F0E).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.35),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _correctAnswer != null ? 'Wrong Answer' : 'Game Over',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (_correctAnswer != null) ...[
                    const SizedBox(height: 8),
                    if (_lastWrongPrompt != null) ...[
                      Text(
                        'Question:',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lastWrongPrompt!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_lastWrongSelected != null) ...[
                      Text(
                        'Your Answer:',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lastWrongSelected!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Correct Answer:',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _correctAnswer!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _answerExplanation ?? '',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text('Level reached: $_level'),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _correctAnswer != null
                          ? _resumeAfterWrong
                          : _resumeAfterDeath,
                      child: Text('Resume (-$_resumeCost coins)'),
                    ),
                  ),
                  if (_coins < _resumeCost) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Need $_resumeCost coins to resume.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.mutedInk),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _startNewGame,
                      child: const Text('Start Over'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VitalsPill extends StatelessWidget {
  final double health;
  final double shield;
  final bool hidden;
  final double powerSeconds;

  const _VitalsPill({
    required this.health,
    required this.shield,
    required this.hidden,
    required this.powerSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0D0C).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MiniBar(label: 'HP', value: health, color: AppColors.secondary),
            const SizedBox(height: 4),
            _MiniBar(label: 'SP', value: shield, color: AppColors.accent),
            if (powerSeconds > 0) ...[
              const SizedBox(height: 4),
              _MiniBar(
                label: 'PB',
                value: (powerSeconds / 10 * 100).clamp(0, 100),
                color: AppColors.danger,
              ),
            ],
            if (hidden) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.visibility_off, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Hidden',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final int level;
  final int stage;
  final int kills;
  final int killsTarget;
  final int coins;
  final int weaponLevel;

  const _ScorePill({
    required this.level,
    required this.stage,
    required this.kills,
    required this.killsTarget,
    required this.coins,
    required this.weaponLevel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0D0C).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.18)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Wave $level  •  K $kills/$killsTarget  •  \$ $coins  •  Wp $weaponLevel',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  fontSize: 10,
                ),
          ),
        ),
      ),
    );
  }
}

class _QuitPill extends StatelessWidget {
  final VoidCallback onPressed;

  const _QuitPill({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0D0C).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.exit_to_app_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Quit',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final String label;

  const _HudChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.danger, size: 20),
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
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
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
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniInfo({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.danger, size: 18),
        ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.mutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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

class _ZombieBackdrop extends StatelessWidget {
  const _ZombieBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ZombieBackdropPainter(),
      child: Container(),
    );
  }
}

class _ZombieBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF0A120E),
          Color(0xFF0E1A14),
          Color(0xFF131E18),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final moon = Paint()..color = const Color(0xFFEDEAD2).withValues(alpha: 0.22);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.18), 52, moon);

    final fog = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.62, size.width, size.height * 0.2),
      fog,
    );

    final ground = Paint()
      ..color = const Color(0xFF08110C).withValues(alpha: 0.85);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.3),
      ground,
    );

    final silhouette = Paint()
      ..color = const Color(0xFF0B1410).withValues(alpha: 0.9);
    for (var i = 0; i < 6; i += 1) {
      final x = size.width * (0.08 + i * 0.14);
      final y = size.height * (0.7 + (i.isEven ? 0.02 : 0.0));
      final body = Rect.fromCenter(
        center: Offset(x, y),
        width: 14,
        height: 28,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(6)),
        silhouette,
      );
      canvas.drawCircle(Offset(x, y - 20), 8, silhouette);
      canvas.drawLine(
        Offset(x - 10, y - 5),
        Offset(x + 10, y - 10),
        silhouette..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HorrorVignette extends StatelessWidget {
  final Animation<double> pulse;

  const _HorrorVignette({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = pulse.value;
        final vignette = 0.2 + t * 0.12;
        final glow = 0.08 + t * 0.08;
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.05,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: vignette),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                  stops: const [0.0, 0.65, 1.0],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2B0E0E).withValues(alpha: glow),
                    Colors.transparent,
                    const Color(0xFF1B0B0B).withValues(alpha: glow + 0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  final Color color;
  final double size;

  const _BackdropGlow({
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.32),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MiniBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 18,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.mutedInk, fontSize: 10),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: value.clamp(0, 100) / 100,
              backgroundColor: AppColors.outline,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _FireButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Animation<double>? pulse;

  const _FireButton({this.onPressed, this.pulse});

  @override
  Widget build(BuildContext context) {
    final content = GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFC13B2A), Color(0xFF6E0F0F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );

    final anim = pulse;
    if (anim == null) {
      return content;
    }
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final t = anim.value;
        return Transform.scale(
          scale: 0.97 + (t * 0.03),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.25 + t * 0.25),
                  blurRadius: 16 + t * 8,
                  spreadRadius: 1 + t * 2,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: content,
    );
  }
}

class _QuizOptionTile extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _QuizOptionTile({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        side: BorderSide(color: AppColors.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ).copyWith(
        backgroundColor: WidgetStateProperty.all(
          AppColors.surface.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.outline),
            ),
            child: Icon(
              Icons.radio_button_unchecked,
              size: 16,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}


class SurvivalQuizGame extends FlameGame with HasCollisionDetection {
  final VoidCallback onQuizTrigger;
  final ValueChanged<int> onKillsChanged;
  final ValueChanged<double> onHealthChanged;
  final ValueChanged<double> onShieldChanged;
  final ValueChanged<int> onWeaponChanged;
  final ValueChanged<int> onCoinsChanged;
  final VoidCallback onGameOver;
  final VoidCallback? onPlayerHit;
  final ValueChanged<bool>? onBossStateChanged;
  final ValueChanged<bool>? onHiddenChanged;
  final ValueChanged<String>? onPickupReward;
  final ValueChanged<double>? onPowerChanged;

  SurvivalQuizGame({
    required this.onQuizTrigger,
    required this.onKillsChanged,
    required this.onHealthChanged,
    required this.onShieldChanged,
    required this.onWeaponChanged,
    required this.onCoinsChanged,
    required this.onGameOver,
    this.onPlayerHit,
    this.onBossStateChanged,
    this.onHiddenChanged,
    this.onPickupReward,
    this.onPowerChanged,
  });

  final Random _random = Random();
  JoystickComponent? _joystick;
  SimpleBackground? _background;
  PlayerComponent? _player;
  final List<ZombieComponent> _zombies = [];
  final List<BulletComponent> _bullets = [];
  final List<PickupComponent> _pickups = [];
  final List<_MapObject> _obstacles = [];

  Vector2 _worldSize = Vector2.zero();
  bool _quizActive = false;
  bool _timersReady = false;
  bool _initialized = false;
  bool _bossAlive = false;
  bool _playerHidden = false;
  int _mapVariant = 0;

  int _level = 1;
  int _kills = 0;
  int _waveTarget = 5;
  int _spawnedThisWave = 0;
  double _health = 100;
  double _shield = 0;
  int _weaponLevel = 1;
  int _coins = 0;
  double _bulletBoost = 1.0;
  double _powerTimer = 0;
  double _lastPowerReport = -1;
  double _contactCooldown = 0;
  static const double _powerDuration = 10;

  late Timer _spawnTimer;
  late Timer _quizTimer;

  int _waveTargetForLevel(int level) {
    return 5 + max(0, level - 1) * 2;
  }

  @override
  Color backgroundColor() {
    return const Color(0xFF0D1B12);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _worldSize = size.clone();
    _background = SimpleBackground()..size = _worldSize;
    _mapVariant = 0;
    _background!.setVariant(_mapVariant);
    _background!.applyLayout(_worldSize);
    await world.add(_background!);
    _refreshObstacles();

    _player = PlayerComponent();
    _player!.position = _worldSize / 2;
    await world.add(_player!);

    _joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 22,
        paint: Paint()..color = AppColors.secondary.withValues(alpha: 0.9),
      ),
      background: CircleComponent(
        radius: 60,
        paint: Paint()..color = Colors.black.withValues(alpha: 0.25),
      ),
      position: Vector2(90, _worldSize.y - 90),
      anchor: Anchor.center,
    );
    camera.viewport.add(_joystick!);

    camera.viewfinder.position = _worldSize / 2;
    _setupTimers();
    _initialized = true;
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (size.x <= 0 || size.y <= 0) return;
    _worldSize = size.clone();
    if (!_initialized) return;
    if (_background != null) {
      _background!.applyLayout(_worldSize);
      _refreshObstacles();
    }
    if (_player != null) {
      final current = _player!.position;
      _player!.position = Vector2(
        current.x.clamp(_player!.radius, _worldSize.x - _player!.radius),
        current.y.clamp(_player!.radius, _worldSize.y - _player!.radius),
      );
      _player!.position = _resolveObstacles(_player!, _player!.position);
    }
    if (_joystick != null) {
      _joystick!.position = Vector2(90, _worldSize.y - 90);
    }
    if (_player != null) {
      camera.viewfinder.position = _player!.position.clone();
    } else {
      camera.viewfinder.position = _worldSize / 2;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_quizActive) return;
    if (_joystick == null) return;

    if (_contactCooldown > 0) {
      _contactCooldown = max(0, _contactCooldown - dt);
    }

    _spawnTimer.update(dt);
    _quizTimer.update(dt);
    if (_powerTimer > 0) {
      _powerTimer = max(0, _powerTimer - dt);
      final report = _powerTimer.ceilToDouble();
      if (report != _lastPowerReport) {
        _lastPowerReport = report;
        onPowerChanged?.call(_powerTimer);
      }
      if (_powerTimer == 0) {
        _bulletBoost = 1.0;
        onPowerChanged?.call(0);
      }
    }

    _updatePlayer(dt);
    _updateHiddenState();
    _updateZombies(dt);
    _updateBullets(dt);
    _updatePickups();
    _updateMapObjects();
  }

  void _setupTimers() {
    if (_timersReady) {
      _spawnTimer.stop();
      _quizTimer.stop();
    }
    _waveTarget = _waveTargetForLevel(_level);
    _spawnedThisWave = 0;
    final spawnInterval = max(0.7, 1.8 - (_level * 0.12));
    _spawnTimer = Timer(spawnInterval, onTick: _spawnZombie, repeat: true)
      ..start();
    _quizTimer = Timer(9999, onTick: _triggerQuiz);
    _timersReady = true;
  }

  void _refreshObstacles() {
    _obstacles
      ..clear()
      ..addAll(
        _background?._objectsView.where((object) => object.isSolid) ??
            const <_MapObject>[],
      );
  }

  void _updatePlayer(double dt) {
    final player = _player;
    final joystick = _joystick;
    if (player == null || joystick == null) return;
    final direction = joystick.relativeDelta;
    if (joystick.intensity < 0.02 || direction.length < 0.05) {
      player.step(Vector2.zero());
      return;
    }
    final move = direction.normalized() * player.speed * dt;
    final next = player.position + move;
    var resolved = Vector2(
      next.x.clamp(player.radius, _worldSize.x - player.radius),
      next.y.clamp(player.radius, _worldSize.y - player.radius),
    );
    resolved = _resolveObstacles(player, resolved);
    player.position = resolved;
    player.step(direction);
  }

  void _updateHiddenState() {
    final player = _player;
    final background = _background;
    if (player == null || background == null) return;
    final hidden = _isPlayerInBush(player.position, player.radius);
    if (hidden != _playerHidden) {
      _playerHidden = hidden;
      onHiddenChanged?.call(hidden);
    }
  }

  bool _isPlayerInBush(Vector2 position, double radius) {
    final objects = _background?._objectsView ?? const <_MapObject>[];
    for (final object in objects) {
      if (object.type != MapObjectType.bush) continue;
      final distance = (object.position - position).length;
      if (distance < object.radius + radius * 0.6) {
        return true;
      }
    }
    return false;
  }

  Vector2 _resolveObstacles(PlayerComponent player, Vector2 next) {
    var resolved = next.clone();
    for (final obstacle in _obstacles) {
      if (!obstacle.isSolid) continue;
      final toPlayer = resolved - obstacle.position;
      final distance = toPlayer.length;
      final minDistance = player.radius + obstacle.radius;
      if (distance < minDistance) {
        final pushDir = distance == 0 ? Vector2(1, 0) : toPlayer.normalized();
        resolved += pushDir * (minDistance - distance + 0.5);
      }
    }
    resolved.x = resolved.x.clamp(player.radius, _worldSize.x - player.radius);
    resolved.y = resolved.y.clamp(player.radius, _worldSize.y - player.radius);
    return resolved;
  }

  void _updateZombies(double dt) {
    final player = _player;
    if (player == null) return;
    for (final zombie in List<ZombieComponent>.from(_zombies)) {
      var toPlayer = player.position - zombie.position;
      if (toPlayer.length > 1) {
        final hideRange = 70.0;
        final shouldHide = _playerHidden && toPlayer.length > hideRange;
        final desired = shouldHide
            ? zombie.pickWanderDirection(_random, dt)
            : toPlayer.normalized();
        var avoid = Vector2.zero();
        for (final obstacle in _obstacles) {
          final toObstacle = zombie.position - obstacle.position;
          final distance = toObstacle.length;
          final influence = zombie.radius + obstacle.radius + 36;
          if (distance < influence && distance > 0) {
            final strength = (influence - distance) / influence;
            avoid += toObstacle.normalized() * (strength * 1.4);
          }
        }
        final steering = (desired + avoid).normalized();
        final speed = shouldHide ? zombie.speed * 0.35 : zombie.speed;
        zombie.position += steering * speed * dt;
        zombie.position = _resolveZombieObstacles(zombie, zombie.position);
      }
      toPlayer = player.position - zombie.position;
      if (zombie.isBoss) {
        zombie.specialCooldown = max(0, zombie.specialCooldown - dt);
        if (zombie.specialCooldown <= 0) {
          const bossRange = 120.0;
          zombie.specialCooldown = 3.4;
          world.add(BossShockwave(
            position: zombie.position.clone(),
            maxRadius: bossRange,
          ));
          if (toPlayer.length < bossRange) {
            _applyDamage(24);
            final push = toPlayer.length == 0
                ? Vector2(1, 0)
                : toPlayer.normalized();
            final bounce = push * 26;
            player.position = Vector2(
              (player.position.x + bounce.x)
                  .clamp(player.radius, _worldSize.x - player.radius),
              (player.position.y + bounce.y)
                  .clamp(player.radius, _worldSize.y - player.radius),
            );
            _contactCooldown = 0.6;
          }
        }
      }
      if (_contactCooldown <= 0 &&
          toPlayer.length < zombie.radius + player.radius) {
        _applyDamage(zombie.contactDamage);
        final push = toPlayer.length == 0
            ? Vector2(1, 0)
            : toPlayer.normalized();
        final bounce = push * 18;
        player.position = Vector2(
          (player.position.x + bounce.x)
              .clamp(player.radius, _worldSize.x - player.radius),
          (player.position.y + bounce.y)
              .clamp(player.radius, _worldSize.y - player.radius),
        );
        zombie.position = Vector2(
          (zombie.position.x - bounce.x * 0.6)
              .clamp(zombie.radius, _worldSize.x - zombie.radius),
          (zombie.position.y - bounce.y * 0.6)
              .clamp(zombie.radius, _worldSize.y - zombie.radius),
        );
        _contactCooldown = 0.6;
      }
    }
  }

  void _updateBullets(double dt) {
    if (_bullets.isEmpty) return;
    final toRemove = <BulletComponent>[];
    for (final bullet in _bullets) {
      bullet.position += bullet.velocity * dt;
      final hitObject = _hitMapObject(bullet.position, bullet.radius);
      if (hitObject != null) {
        _handleMapObjectHit(hitObject);
        toRemove.add(bullet);
        continue;
      }
      if (bullet.position.x < -20 ||
          bullet.position.y < -20 ||
          bullet.position.x > _worldSize.x + 20 ||
          bullet.position.y > _worldSize.y + 20) {
        toRemove.add(bullet);
      }
    }
    for (final bullet in toRemove) {
      bullet.removeFromParent();
      _bullets.remove(bullet);
    }
  }

  Vector2 _resolveZombieObstacles(ZombieComponent zombie, Vector2 next) {
    var resolved = next.clone();
    for (final obstacle in _obstacles) {
      if (!obstacle.isSolid) continue;
      final toZombie = resolved - obstacle.position;
      final distance = toZombie.length;
      final minDistance = zombie.radius + obstacle.radius;
      if (distance < minDistance) {
        final pushDir = distance == 0 ? Vector2(1, 0) : toZombie.normalized();
        resolved += pushDir * (minDistance - distance + 0.4);
      }
    }
    resolved.x = resolved.x.clamp(zombie.radius, _worldSize.x - zombie.radius);
    resolved.y = resolved.y.clamp(zombie.radius, _worldSize.y - zombie.radius);
    return resolved;
  }

  _MapObject? _hitMapObject(Vector2 position, double radius) {
    final objects = _background?._objectsView ?? const <_MapObject>[];
    for (final object in objects) {
      if (!object.isSolid) continue;
      final distance = (object.position - position).length;
      if (distance < object.radius + radius) {
        return object;
      }
    }
    return null;
  }

  void _handleMapObjectHit(_MapObject object) {
    if (object.opened) return;
    if (object.type == MapObjectType.crate) {
      object.opened = true;
      _spawnPickupAt(object.position);
      return;
    }
    if (object.type == MapObjectType.tree ||
        object.type == MapObjectType.rock ||
        object.type == MapObjectType.relic) {
      object.opened = true;
      if (_random.nextDouble() < 0.35) {
        _spawnPickupAt(object.position);
      }
    }
  }

  void _updatePickups() {
    final player = _player;
    if (player == null) return;
    for (final pickup in List<PickupComponent>.from(_pickups)) {
      if ((pickup.position - player.position).length < pickup.radius + player.radius) {
        _applyPickup(pickup);
      }
    }
  }

  void _updateMapObjects() {
    final player = _player;
    final background = _background;
    if (player == null || background == null) return;
    for (final object in background._objectsView) {
      if (!object.isInteractive || object.opened) continue;
      final distance = (object.position - player.position).length;
      if (distance < object.radius + player.radius + 4) {
        if (object.type == MapObjectType.crate) {
          object.opened = true;
          _spawnPickupAt(object.position);
        } else if (object.type == MapObjectType.bush) {
          if (!object.searched && _random.nextDouble() < 0.4) {
            object.searched = true;
            final type = _random.nextBool()
                ? PickupType.coins
                : PickupType.medkit;
            _spawnPickupAt(object.position, type: type);
          }
        }
      }
    }
  }

  void _spawnPickupAt(Vector2 position, {PickupType? type}) {
    final pickup = type == null
        ? PickupComponent.random(position: position)
        : PickupComponent(type: type, position: position);
    _pickups.add(pickup);
    world.add(pickup);
  }

  void _spawnZombie() {
    if (_quizActive) return;
    if (_spawnedThisWave >= _waveTarget) return;
    final edge = _random.nextInt(4);
    double x = 0;
    double y = 0;
    if (edge == 0) {
      x = _random.nextDouble() * _worldSize.x;
      y = -10;
    } else if (edge == 1) {
      x = _worldSize.x + 10;
      y = _random.nextDouble() * _worldSize.y;
    } else if (edge == 2) {
      x = _random.nextDouble() * _worldSize.x;
      y = _worldSize.y + 10;
    } else {
      x = -10;
      y = _random.nextDouble() * _worldSize.y;
    }

    final zombie = ZombieComponent.fromLevel(
      level: _level,
      position: Vector2(x, y),
      mapVariant: _mapVariant,
    );
    _zombies.add(zombie);
    world.add(zombie);
    _spawnedThisWave += 1;
  }

  void _spawnBoss() {
    if (_bossAlive || _quizActive) return;
    final position = Vector2(_worldSize.x * 0.5, _worldSize.y * 0.2);
    final boss = ZombieComponent.boss(
      level: _level,
      position: position,
      mapVariant: _mapVariant,
    );
    _bossAlive = true;
    onBossStateChanged?.call(true);
    _background?.setBossMode(true);
    _refreshObstacles();
    _zombies.add(boss);
    world.add(boss);
  }

  void _handleZombieDown(ZombieComponent zombie) {
    zombie.removeFromParent();
    _zombies.remove(zombie);
    if (zombie.isBoss) {
      _bossAlive = false;
      onBossStateChanged?.call(false);
      _background?.setBossMode(false);
      _refreshObstacles();
      addCoins(50);
      onCoinsChanged(_coins);
      addShield(25);
      onShieldChanged(_shield);
      addHealth(25);
      onHealthChanged(_health);
      addPowerBullets();
      onPickupReward?.call('Boss reward: Power bullets');
    }
    _kills += 1;
    onKillsChanged(_kills);
    if (_random.nextDouble() < 0.35) {
      final pickup = PickupComponent.random(position: zombie.position);
      _pickups.add(pickup);
      world.add(pickup);
    }
    if (_bossAlive) {
      return;
    }
    if (_spawnedThisWave >= _waveTarget && _zombies.isEmpty) {
      _triggerQuiz();
    }
  }

  void _triggerQuiz() {
    if (_quizActive) return;
    _quizActive = true;
    pauseEngine();
    onQuizTrigger();
  }

  void _applyDamage(double damage) {
    if (_shield > 0) {
      final shieldLeft = _shield - damage;
      if (shieldLeft < 0) {
        _shield = 0;
        _health = max(0, _health + shieldLeft);
      } else {
        _shield = shieldLeft;
      }
      onShieldChanged(_shield);
    } else {
      _health = max(0, _health - damage);
      onHealthChanged(_health);
    }
    onPlayerHit?.call();
    if (_health <= 0) {
      onGameOver();
      pauseEngine();
    }
  }

  void _applyPickup(PickupComponent pickup) {
    switch (pickup.type) {
      case PickupType.medkit:
        addHealth(20);
        onPickupReward?.call('+20 Health');
        break;
      case PickupType.shield:
        addShield(15);
        onPickupReward?.call('+15 Shield');
        break;
      case PickupType.weapon:
        upgradeWeapon();
        onPickupReward?.call('Weapon upgrade');
        break;
      case PickupType.coins:
        addCoins(10);
        onPickupReward?.call('+10 Coins');
        break;
      case PickupType.power:
        addPowerBullets();
        onPickupReward?.call('Power bullets');
        break;
    }
    pickup.removeFromParent();
    _pickups.remove(pickup);
  }

  void attack() {
    if (_quizActive) return;
    final player = _player;
    if (player == null) return;
    final joystick = _joystick;
    final direction = joystick != null && joystick.intensity > 0.05
        ? joystick.relativeDelta.normalized()
        : player.facing;
    final velocity = direction * (260 + _weaponLevel * 30);
    final bullet = BulletComponent(
      position: player.position + direction * (player.radius + 8),
      velocity: velocity,
      damage: (18 + _weaponLevel * 4) * _bulletBoost,
    );
    bullet.onHitZombie = _handleBulletHit;
    _bullets.add(bullet);
    world.add(bullet);
  }

  void _handleBulletHit(BulletComponent bullet, ZombieComponent zombie) {
    if (!_bullets.contains(bullet) || !_zombies.contains(zombie)) return;
    zombie.health -= bullet.damage;
    bullet.markForRemoval();
    bullet.removeFromParent();
    _bullets.remove(bullet);
    if (zombie.health <= 0) {
      _handleZombieDown(zombie);
    }
  }

  void nextLevel(int level) {
    _level = level;
    _kills = 0;
    _waveTarget = _waveTargetForLevel(_level);
    _spawnedThisWave = 0;
    _quizActive = false;
    onKillsChanged(_kills);
    for (final zombie in List<ZombieComponent>.from(_zombies)) {
      zombie.removeFromParent();
    }
    _zombies.clear();
    final stage = ((_level - 1) ~/ 3) + 1;
    _mapVariant = (stage - 1) % 3;
    _background?.setVariant(_mapVariant);
    _background?.setBossMode(_level % 3 == 0);
    _refreshObstacles();
    if (_level % 3 == 0) {
      _spawnBoss();
    } else if (_bossAlive) {
      _bossAlive = false;
      onBossStateChanged?.call(false);
    }
    _setupTimers();
    resumeEngine();
  }

  void reset() {
    _level = 1;
    _kills = 0;
    _waveTarget = _waveTargetForLevel(_level);
    _spawnedThisWave = 0;
    _health = 100;
    _shield = 0;
    _weaponLevel = 1;
    _coins = 0;
    _bulletBoost = 1.0;
    _powerTimer = 0;
    _lastPowerReport = -1;
    onPowerChanged?.call(0);
    _quizActive = false;
    _bossAlive = false;
    onBossStateChanged?.call(false);
    _mapVariant = 0;
    _background?.setVariant(_mapVariant);
    _background?.setBossMode(false);
    _refreshObstacles();
    onHealthChanged(_health);
    onShieldChanged(_shield);
    onWeaponChanged(_weaponLevel);
    onKillsChanged(_kills);
    onCoinsChanged(_coins);
    for (final zombie in List<ZombieComponent>.from(_zombies)) {
      zombie.removeFromParent();
    }
    _zombies.clear();
    for (final bullet in List<BulletComponent>.from(_bullets)) {
      bullet.removeFromParent();
    }
    _bullets.clear();
    for (final pickup in List<PickupComponent>.from(_pickups)) {
      pickup.removeFromParent();
    }
    _pickups.clear();
    if (_player != null) {
      _player!.position = _worldSize / 2;
    }
    _setupTimers();
    resumeEngine();
  }

  void addHealth(double amount) {
    _health = min(100, _health + amount);
    onHealthChanged(_health);
  }

  void addShield(double amount) {
    _shield = min(100, _shield + amount);
    onShieldChanged(_shield);
  }

  void upgradeWeapon() {
    _weaponLevel = min(4, _weaponLevel + 1);
    onWeaponChanged(_weaponLevel);
  }

  void addPowerBullets() {
    _bulletBoost = 1.6;
    _powerTimer = _powerDuration;
    _lastPowerReport = -1;
    onPowerChanged?.call(_powerTimer);
  }

  bool spendCoins(int amount) {
    if (amount <= 0) {
      return true;
    }
    if (_coins < amount) {
      return false;
    }
    _coins -= amount;
    onCoinsChanged(_coins);
    return true;
  }

  void addCoins(int amount) {
    _coins += amount;
    onCoinsChanged(_coins);
  }

  void revive({double health = 60, double shield = 0}) {
    _health = health.clamp(0, 100);
    _shield = shield.clamp(0, 100);
    onHealthChanged(_health);
    onShieldChanged(_shield);
    if (_player != null) {
      _player!.position = _worldSize / 2;
    }
    _contactCooldown = 1.2;
  }

  void clearZombies() {
    for (final zombie in List<ZombieComponent>.from(_zombies)) {
      zombie.removeFromParent();
    }
    _zombies.clear();
    if (_bossAlive) {
      _bossAlive = false;
      onBossStateChanged?.call(false);
      _background?.setBossMode(false);
      _refreshObstacles();
    }
  }

  Vector2 get playerPosition {
    final player = _player;
    if (player == null) {
      return _worldSize / 2;
    }
    return player.position.clone();
  }

  void restoreFromSave(SurvivalGameSave save) {
    _level = max(1, save.level);
    _kills = max(0, save.kills);
    _coins = max(0, save.coins);
    _health = save.health.clamp(0, 100);
    _shield = save.shield.clamp(0, 100);
    _weaponLevel = max(1, min(4, save.weaponLevel));
    _waveTarget = _waveTargetForLevel(_level);
    _spawnedThisWave = min(_kills, _waveTarget);
    _quizActive = false;
    final stage = ((_level - 1) ~/ 3) + 1;
    _mapVariant = (stage - 1) % 3;
    _background?.setVariant(_mapVariant);
    _background?.setBossMode(_level % 3 == 0);
    _refreshObstacles();
    _bulletBoost = 1.0;
    _powerTimer = 0;
    _lastPowerReport = -1;
    onPowerChanged?.call(0);

    onKillsChanged(_kills);
    onCoinsChanged(_coins);
    onHealthChanged(_health);
    onShieldChanged(_shield);
    onWeaponChanged(_weaponLevel);

    for (final zombie in List<ZombieComponent>.from(_zombies)) {
      zombie.removeFromParent();
    }
    _zombies.clear();
    for (final bullet in List<BulletComponent>.from(_bullets)) {
      bullet.removeFromParent();
    }
    _bullets.clear();
    for (final pickup in List<PickupComponent>.from(_pickups)) {
      pickup.removeFromParent();
    }
    _pickups.clear();

    if (_player != null) {
      final clampedX = save.playerX.clamp(_player!.radius, _worldSize.x - _player!.radius);
      final clampedY = save.playerY.clamp(_player!.radius, _worldSize.y - _player!.radius);
      _player!.position = Vector2(clampedX, clampedY);
    }

    if (_level % 3 == 0 && !_bossAlive) {
      _spawnBoss();
    }
    _setupTimers();
    resumeEngine();
  }

  void resumeAfterQuiz() {
    _quizActive = false;
    resumeEngine();
  }
}

class SimpleBackground extends PositionComponent {
  int _variant = 0;
  bool _bossMode = false;
  final List<Color> _grounds = const [
    Color(0xFF0E1F16),
    Color(0xFF1A1B2F),
    Color(0xFF2A1A12),
  ];
  final List<Color> _paths = const [
    Color(0xFF2B2A1D),
    Color(0xFF30314A),
    Color(0xFF3B241A),
  ];
  final List<Color> _treeLeaves = const [
    Color(0xFF2E7D32),
    Color(0xFF2E5F99),
    Color(0xFF9C6B2F),
  ];
  final List<Color> _treeTrunks = const [
    Color(0xFF5D4037),
    Color(0xFF4E3B6B),
    Color(0xFF6E4A2F),
  ];
  final List<Color> _rockColors = const [
    Color(0xFF6B6E6D),
    Color(0xFF5B5D6E),
    Color(0xFF7A6552),
  ];
  final List<Color> _crateColors = const [
    Color(0xFF8B5A2B),
    Color(0xFF73659C),
    Color(0xFF8B5A2B),
  ];
  final List<Color> _bushColors = const [
    Color(0xFF3E8B4A),
    Color(0xFF3A4C87),
    Color(0xFF7C5A37),
  ];
  final List<Color> _relicColors = const [
    Color(0xFFB5523B),
    Color(0xFF6B4BA8),
    Color(0xFFB87333),
  ];
  final Paint _fog = Paint()..color = Colors.white.withValues(alpha: 0.05);
  final List<_MapObject> _objects = [];

  void setVariant(int value) {
    _variant = value % _grounds.length;
    _generateObjects();
  }

  void setBossMode(bool value) {
    _bossMode = value;
    _generateObjects();
  }

  void applyLayout(Vector2 newSize) {
    size = newSize;
    _generateObjects();
  }

  Rect _pathRect() {
    return Rect.fromLTWH(
      size.x * 0.18,
      size.y * 0.2,
      size.x * 0.64,
      size.y * 0.6,
    );
  }

  void _generateObjects() {
    if (size.x <= 0 || size.y <= 0) return;
    _objects.clear();
    final seed = _variant * 1000 + size.x.round() + size.y.round();
    final rand = Random(seed);
    final types = switch (_variant) {
      0 => [
          MapObjectType.tree,
          MapObjectType.bush,
          MapObjectType.rock,
          MapObjectType.crate,
        ],
      1 => [
          MapObjectType.rock,
          MapObjectType.tree,
          MapObjectType.crate,
          MapObjectType.bush,
        ],
      _ => [
          MapObjectType.rock,
          MapObjectType.bush,
          MapObjectType.crate,
          MapObjectType.tree,
        ],
    };
    final pathRect = _pathRect().inflate(18);
    final margin = 22.0;
    final count = 9 + rand.nextInt(4);
    for (var i = 0; i < count; i += 1) {
      var attempts = 0;
      Vector2 pos = Vector2.zero();
      while (attempts < 20) {
        final x = margin + rand.nextDouble() * (size.x - margin * 2);
        final y = margin + rand.nextDouble() * (size.y - margin * 2);
        pos = Vector2(x, y);
        if (!pathRect.contains(Offset(pos.x, pos.y))) {
          break;
        }
        attempts += 1;
      }
      if (attempts >= 20) continue;
      final radius = 10 + rand.nextDouble() * 12;
      final type = types[rand.nextInt(types.length)];
      _objects.add(_MapObject(
        type: type,
        position: pos,
        radius: radius,
        rotation: rand.nextDouble() * pi,
      ));
    }

    if (_bossMode) {
      final relicCount = 2 + rand.nextInt(2);
      for (var i = 0; i < relicCount; i += 1) {
        var attempts = 0;
        Vector2 pos = Vector2.zero();
        while (attempts < 20) {
          final x = margin + rand.nextDouble() * (size.x - margin * 2);
          final y = margin + rand.nextDouble() * (size.y - margin * 2);
          pos = Vector2(x, y);
          if (!pathRect.contains(Offset(pos.x, pos.y))) {
            break;
          }
          attempts += 1;
        }
        if (attempts >= 20) continue;
        final radius = 16 + rand.nextDouble() * 10;
        _objects.add(_MapObject(
          type: MapObjectType.relic,
          position: pos,
          radius: radius,
          rotation: rand.nextDouble() * pi,
        ));
      }
    }
  }

  List<_MapObject> get _objectsView => List.unmodifiable(_objects);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (_objects.isEmpty) {
      _generateObjects();
    }
    final groundPaint = Paint()..color = _grounds[_variant];
    final pathPaint = Paint()..color = _paths[_variant];
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(rect, groundPaint);
    final pathRect = _pathRect();
    canvas.drawRRect(RRect.fromRectAndRadius(pathRect, const Radius.circular(24)), pathPaint);
    for (final object in _objects) {
      _renderObject(canvas, object);
    }
    canvas.drawRect(rect, _fog);
  }

  void _renderObject(Canvas canvas, _MapObject object) {
    canvas.save();
    canvas.translate(object.position.x, object.position.y);
    canvas.rotate(object.rotation);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, object.radius * 0.6),
        width: object.radius * 1.6,
        height: object.radius * 0.6,
      ),
      shadowPaint,
    );

    switch (object.type) {
      case MapObjectType.tree:
        final leaf = Paint()
          ..color = object.opened
              ? _treeLeaves[_variant].withValues(alpha: 0.25)
              : _treeLeaves[_variant];
        final trunk = Paint()
          ..color = object.opened
              ? _treeTrunks[_variant].withValues(alpha: 0.45)
              : _treeTrunks[_variant];
        if (!object.opened) {
          canvas.drawCircle(
            Offset(0, -object.radius * 0.4),
            object.radius * 0.8,
            leaf,
          );
          canvas.drawCircle(
            Offset(-object.radius * 0.5, -object.radius * 0.1),
            object.radius * 0.6,
            leaf,
          );
          canvas.drawCircle(
            Offset(object.radius * 0.5, -object.radius * 0.1),
            object.radius * 0.6,
            leaf,
          );
        }
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(0, object.radius * 0.5),
            width: object.radius * 0.4,
            height: object.radius * (object.opened ? 0.6 : 1.1),
          ),
          trunk,
        );
        break;
      case MapObjectType.rock:
        final rock = Paint()
          ..color = object.opened
              ? _rockColors[_variant].withValues(alpha: 0.3)
              : _rockColors[_variant];
        final width = object.radius * (object.opened ? 1.1 : 1.8);
        final height = object.radius * (object.opened ? 0.7 : 1.2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: width,
              height: height,
            ),
            Radius.circular(object.radius * 0.4),
          ),
          rock,
        );
        break;
      case MapObjectType.crate:
        final crate = Paint()
          ..color = object.opened
              ? _crateColors[_variant].withValues(alpha: 0.4)
              : _crateColors[_variant];
        final edge = Paint()
          ..color = Colors.black.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: object.radius * 1.6,
          height: object.radius * 1.2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(object.radius * 0.2)),
          crate,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(object.radius * 0.2)),
          edge,
        );
        if (!object.opened) {
          canvas.drawLine(
            Offset(-rect.width * 0.3, -rect.height * 0.2),
            Offset(rect.width * 0.3, rect.height * 0.2),
            edge,
          );
          canvas.drawLine(
            Offset(rect.width * 0.3, -rect.height * 0.2),
            Offset(-rect.width * 0.3, rect.height * 0.2),
            edge,
          );
        }
        break;
      case MapObjectType.bush:
        final bush = Paint()
          ..color = object.searched
              ? _bushColors[_variant].withValues(alpha: 0.5)
              : _bushColors[_variant];
        canvas.drawCircle(Offset(-object.radius * 0.4, 0), object.radius * 0.6, bush);
        canvas.drawCircle(Offset(object.radius * 0.3, 0), object.radius * 0.7, bush);
        canvas.drawCircle(Offset(0, -object.radius * 0.2), object.radius * 0.75, bush);
        break;
      case MapObjectType.relic:
        final relic = Paint()
          ..color = object.opened
              ? _relicColors[_variant].withValues(alpha: 0.3)
              : _relicColors[_variant];
        final glow = Paint()
          ..color = _relicColors[_variant]
              .withValues(alpha: object.opened ? 0.1 : 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        final baseRect = Rect.fromCenter(
          center: Offset(0, object.radius * 0.2),
          width: object.radius * (object.opened ? 1.0 : 1.4),
          height: object.radius * (object.opened ? 0.7 : 1.2),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(baseRect, Radius.circular(object.radius * 0.2)),
          relic,
        );
        if (!object.opened) {
          canvas.drawCircle(
            Offset(0, -object.radius * 0.5),
            object.radius * 0.5,
            relic,
          );
          canvas.drawCircle(
            Offset(0, -object.radius * 0.5),
            object.radius * 0.7,
            glow,
          );
          canvas.drawLine(
            Offset(0, -object.radius * 0.9),
            Offset(0, object.radius * 0.1),
            Paint()
              ..color = Colors.black.withValues(alpha: 0.2)
              ..strokeWidth = 1.2,
          );
        }
        break;
    }

    canvas.restore();
  }
}

enum MapObjectType { tree, rock, crate, bush, relic }

class _MapObject {
  final MapObjectType type;
  final Vector2 position;
  final double radius;
  final double rotation;
  bool opened = false;
  bool searched = false;

  _MapObject({
    required this.type,
    required this.position,
    required this.radius,
    required this.rotation,
  });

  bool get isSolid {
    if (type == MapObjectType.bush) return false;
    if (opened &&
        (type == MapObjectType.crate ||
            type == MapObjectType.tree ||
            type == MapObjectType.rock ||
            type == MapObjectType.relic)) {
      return false;
    }
    return true;
  }

  bool get isInteractive =>
      type == MapObjectType.crate || type == MapObjectType.bush;
}

class PlayerComponent extends PositionComponent {
  double speed = 190;
  final double radius;
  Vector2 facing = Vector2(1, 0);
  double _animTime = 0;

  PlayerComponent({this.radius = 18}) {
    size = Vector2(radius * 2.2, radius * 2.2);
    anchor = Anchor.center;
  }

  void step(Vector2 direction) {
    if (direction.length > 0) {
      facing = direction.normalized();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animTime += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(size.x / 2, size.y / 2);
    final angle = atan2(facing.y, facing.x);
    final swing = sin(_animTime * 6) * 6;
    final bodyPaint = Paint()..color = const Color(0xFFFFD166);
    final clothPaint = Paint()..color = const Color(0xFF3A6EA5);
    final outline = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final limbPaint = Paint()
      ..color = const Color(0xFF2F2F2F)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    final bodyWidth = radius * 0.9;
    final bodyHeight = radius * 1.3;
    final headRadius = radius * 0.45;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, radius * 0.9),
        width: radius * 1.6,
        height: radius * 0.6,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );

    canvas.drawLine(
      Offset(-bodyWidth * 0.3, bodyHeight * 0.5),
      Offset(-bodyWidth * 0.35, bodyHeight * 0.5 + 12 + swing * 0.2),
      limbPaint,
    );
    canvas.drawLine(
      Offset(bodyWidth * 0.3, bodyHeight * 0.5),
      Offset(bodyWidth * 0.35, bodyHeight * 0.5 + 12 - swing * 0.2),
      limbPaint,
    );

    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 0), width: bodyWidth, height: bodyHeight),
      Radius.circular(radius * 0.2),
    );
    canvas.drawRRect(torsoRect, clothPaint);
    canvas.drawRRect(torsoRect, outline);

    final bagRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(-bodyWidth * 0.55, 0),
        width: bodyWidth * 0.4,
        height: bodyHeight * 0.8,
      ),
      Radius.circular(radius * 0.15),
    );
    canvas.drawRRect(bagRect, Paint()..color = const Color(0xFF915C2F));
    canvas.drawRRect(bagRect, outline);

    canvas.drawLine(
      Offset(-bodyWidth * 0.5, -bodyHeight * 0.1),
      Offset(-bodyWidth * 0.8, -bodyHeight * 0.1 + swing * 0.3),
      limbPaint,
    );
    canvas.drawLine(
      Offset(bodyWidth * 0.5, -bodyHeight * 0.1),
      Offset(bodyWidth * 0.9, -bodyHeight * 0.1 - swing * 0.3),
      limbPaint,
    );

    final headCenter = Offset(0, -bodyHeight * 0.75);
    canvas.drawCircle(headCenter, headRadius, bodyPaint);
    canvas.drawCircle(headCenter, headRadius, outline);
    canvas.drawCircle(
      headCenter + Offset(headRadius * 0.4, headRadius * 0.1),
      headRadius * 0.12,
      Paint()..color = Colors.black,
    );

    canvas.restore();
  }
}

enum ZombieKind { normal, fast, tank, boss }

class ZombieComponent extends PositionComponent with CollisionCallbacks {
  final double speed;
  double health;
  final double maxHealth;
  final double radius;
  final bool isBoss;
  final double contactDamage;
  final ZombieKind kind;
  final int mapVariant;
  double _animTime = 0;
  double specialCooldown;
  Vector2 wanderDirection = Vector2.zero();
  double wanderTimer = 0;

  ZombieComponent({
    required this.speed,
    required this.health,
    required Vector2 position,
    required this.radius,
    this.isBoss = false,
    required this.contactDamage,
    required this.kind,
    required this.mapVariant,
  })  : maxHealth = health,
        specialCooldown = isBoss ? 2.5 : 0 {
    this.position = position;
    size = Vector2(radius * 2, radius * 2);
    anchor = Anchor.center;
  }

  factory ZombieComponent.fromLevel({
    required int level,
    required Vector2 position,
    required int mapVariant,
  }) {
    switch (mapVariant) {
      case 1:
        return ZombieComponent(
          speed: 60 + level * 7,
          health: 32 + level * 5,
          radius: 13,
          position: position,
          contactDamage: 10,
          kind: ZombieKind.fast,
          mapVariant: mapVariant,
        );
      case 2:
        return ZombieComponent(
          speed: 32 + level * 4,
          health: 70 + level * 12,
          radius: 16,
          position: position,
          contactDamage: 16,
          kind: ZombieKind.tank,
          mapVariant: mapVariant,
        );
      default:
        return ZombieComponent(
          speed: 40 + level * 6,
          health: 40 + level * 8,
          radius: 14,
          position: position,
          contactDamage: 12,
          kind: ZombieKind.normal,
          mapVariant: mapVariant,
        );
    }
  }

  factory ZombieComponent.boss({
    required int level,
    required Vector2 position,
    required int mapVariant,
  }) {
    return ZombieComponent(
      speed: 30 + level * 2,
      health: 280 + level * 30,
      radius: 24,
      position: position,
      isBoss: true,
      contactDamage: 26,
      kind: ZombieKind.boss,
      mapVariant: mapVariant,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(radius: radius));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = Offset(size.x / 2, size.y / 2);
    final swing = sin(_animTime * 5) * 5;
    final bodyPaint = Paint()
      ..color = switch (kind) {
        ZombieKind.fast => const Color(0xFF3FAE5B),
        ZombieKind.tank => const Color(0xFF5C3FAE),
        ZombieKind.boss => const Color(0xFF8B2F2F),
        ZombieKind.normal => const Color(0xFF2E9A8A),
      };
    final outline = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final limbPaint = Paint()
      ..color = switch (mapVariant) {
        1 => const Color(0xFF2A3E6B),
        2 => const Color(0xFF5A3A22),
        _ => const Color(0xFF1A534C),
      }
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, radius * 0.8),
        width: radius * 1.4,
        height: radius * 0.5,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.2),
    );

    final bodyWidth = radius * 0.9;
    final bodyHeight = radius * 1.2;
    final headRadius = radius * 0.5;

    canvas.drawLine(
      Offset(-bodyWidth * 0.2, bodyHeight * 0.5),
      Offset(-bodyWidth * 0.3, bodyHeight * 0.5 + 10 + swing * 0.2),
      limbPaint,
    );
    canvas.drawLine(
      Offset(bodyWidth * 0.2, bodyHeight * 0.5),
      Offset(bodyWidth * 0.3, bodyHeight * 0.5 + 10 - swing * 0.2),
      limbPaint,
    );

    final torsoRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, 0), width: bodyWidth, height: bodyHeight),
      Radius.circular(radius * 0.2),
    );
    canvas.drawRRect(torsoRect, bodyPaint);
    canvas.drawRRect(torsoRect, outline);

    if (kind == ZombieKind.tank) {
      final armor = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, 0),
            width: bodyWidth * 0.85,
            height: bodyHeight * 0.6,
          ),
          Radius.circular(radius * 0.2),
        ),
        armor,
      );
    } else if (kind == ZombieKind.normal) {
      final stitch = Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(0, -bodyHeight * 0.1),
        Offset(0, bodyHeight * 0.3),
        stitch,
      );
      canvas.drawLine(
        Offset(-4, bodyHeight * 0.05),
        Offset(4, bodyHeight * 0.05),
        stitch,
      );
    }

    canvas.drawLine(
      Offset(-bodyWidth * 0.6, -bodyHeight * 0.1),
      Offset(-bodyWidth * 1.0, -bodyHeight * 0.1 + swing * 0.3),
      limbPaint,
    );
    canvas.drawLine(
      Offset(bodyWidth * 0.6, -bodyHeight * 0.1),
      Offset(bodyWidth * 1.0, -bodyHeight * 0.1 - swing * 0.3),
      limbPaint,
    );

    final headCenter = Offset(0, -bodyHeight * 0.75);
    canvas.drawCircle(headCenter, headRadius, bodyPaint);
    canvas.drawCircle(headCenter, headRadius, outline);
    final eyePaint = Paint()
      ..color = isBoss ? const Color(0xFFFF5E5E) : Colors.black;
    canvas.drawCircle(headCenter + const Offset(-3, -2), 2.5, eyePaint);
    canvas.drawCircle(headCenter + const Offset(4, -2), 2.5, eyePaint);
    canvas.drawLine(
      headCenter + const Offset(-4, 5),
      headCenter + const Offset(4, 5),
      Paint()
        ..color = Colors.black
        ..strokeWidth = 2,
    );

    if (kind == ZombieKind.fast) {
      final spike = Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..strokeWidth = 2;
      canvas.drawLine(
        headCenter + Offset(-headRadius * 0.2, -headRadius * 0.6),
        headCenter + Offset(-headRadius * 0.6, -headRadius * 1.1),
        spike,
      );
      canvas.drawLine(
        headCenter + Offset(headRadius * 0.2, -headRadius * 0.6),
        headCenter + Offset(headRadius * 0.6, -headRadius * 1.1),
        spike,
      );
    } else if (kind == ZombieKind.boss) {
      final hornPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..strokeWidth = 2.5;
      canvas.drawLine(
        headCenter + Offset(-headRadius * 0.4, -headRadius * 0.6),
        headCenter + Offset(-headRadius * 0.9, -headRadius * 1.2),
        hornPaint,
      );
      canvas.drawLine(
        headCenter + Offset(headRadius * 0.4, -headRadius * 0.6),
        headCenter + Offset(headRadius * 0.9, -headRadius * 1.2),
        hornPaint,
      );
    }

    canvas.restore();

    final barWidth = radius * 1.9;
    final barHeight = 4.0;
    final pct = maxHealth <= 0 ? 0.0 : (health / maxHealth).clamp(0.0, 1.0);
    final barRect = Rect.fromCenter(
      center: Offset(size.x / 2, -6),
      width: barWidth,
      height: barHeight,
    );
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final hpPaint = Paint()
      ..color = Color.lerp(const Color(0xFFEF4444), const Color(0xFF22C55E), pct)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(4)),
      bgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          barRect.left,
          barRect.top,
          barRect.width * pct,
          barRect.height,
        ),
        const Radius.circular(4),
      ),
      hpPaint,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _animTime += dt;
  }

  Vector2 pickWanderDirection(Random random, double dt) {
    wanderTimer -= dt;
    if (wanderTimer <= 0 || wanderDirection.length == 0) {
      final angle = random.nextDouble() * pi * 2;
      wanderDirection = Vector2(cos(angle), sin(angle));
      wanderTimer = 0.8 + random.nextDouble() * 1.6;
    }
    return wanderDirection;
  }
}

class BulletComponent extends PositionComponent with CollisionCallbacks {
  final Vector2 velocity;
  final double damage;
  final double radius;
  void Function(BulletComponent bullet, ZombieComponent zombie)? onHitZombie;
  bool _spent = false;

  BulletComponent({
    required Vector2 position,
    required this.velocity,
    required this.damage,
  })  : radius = 4,
        super(position: position, size: Vector2.all(8), anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = const Color(0xFFFFC857);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), radius, paint);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox(radius: radius));
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (_spent) return;
    if (other is ZombieComponent) {
      _spent = true;
      onHitZombie?.call(this, other);
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  void markForRemoval() {
    _spent = true;
  }
}

class BossShockwave extends PositionComponent {
  final double maxRadius;
  double _radius = 0;

  BossShockwave({
    required Vector2 position,
    required this.maxRadius,
  }) {
    this.position = position;
    size = Vector2.zero();
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _radius += dt * 140;
    if (_radius >= maxRadius) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final alpha = (1 - (_radius / maxRadius)).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.3 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset.zero, _radius, paint);
  }
}

enum PickupType { medkit, shield, weapon, coins, power }

class PickupComponent extends PositionComponent {
  final PickupType type;
  final double radius;

  PickupComponent({
    required this.type,
    required Vector2 position,
  })  : radius = 8,
        super(position: position, size: Vector2.all(16), anchor: Anchor.center);

  factory PickupComponent.random({required Vector2 position}) {
    final roll = Random().nextInt(100);
    if (roll < 30) {
      return PickupComponent(type: PickupType.coins, position: position);
    }
    if (roll < 55) {
      return PickupComponent(type: PickupType.medkit, position: position);
    }
    if (roll < 75) {
      return PickupComponent(type: PickupType.shield, position: position);
    }
    if (roll < 90) {
      return PickupComponent(type: PickupType.weapon, position: position);
    }
    return PickupComponent(type: PickupType.power, position: position);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()
      ..color = switch (type) {
        PickupType.medkit => const Color(0xFFE84A4A),
        PickupType.shield => const Color(0xFF58A6FF),
        PickupType.weapon => const Color(0xFFFFC857),
        PickupType.coins => const Color(0xFFF4D35E),
        PickupType.power => const Color(0xFF8B5CF6),
      };
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), radius, paint);
  }
}
