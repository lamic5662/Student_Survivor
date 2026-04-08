import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/core/widgets/ai_status_chip.dart';
import 'package:student_survivor/features/ai/ai_presenter.dart';
import 'package:student_survivor/features/ai/ai_view_model.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState
    extends PresenterState<AiAssistantScreen, AiView, AiPresenter>
    implements AiView {
  final _controller = TextEditingController();
  final _inputFocus = FocusNode();
  final _chatSearchController = TextEditingController();
  final _chatSearchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;
  bool _chatsExpanded = false;
  late final stt.SpeechToText _speech;
  late final FlutterTts _tts;
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _ttsReady = false;
  bool _isSpeaking = false;
  bool _autoSpeak = true;
  String? _lastAutoSpoken;
  String? _ttsInfo;
  int? _speakingMessageIndex;
  int _speakingStart = -1;
  int _speakingEnd = -1;
  String? _speakingText;
  int _speakingCursor = 0;
  String? _speakingCursorText;

  @override
  AiPresenter createPresenter() => AiPresenter();

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    _chatSearchController.removeListener(_handleSearchChange);
    _chatSearchController.dispose();
    _chatSearchFocus.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _chatSearchController.addListener(_handleSearchChange);
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initSpeech();
    _initTts();
  }

  void _handleScroll() {
    final shouldShow = _scrollController.offset < 24;
    if (shouldShow != _showTitle) {
      setState(() => _showTitle = shouldShow);
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    presenter.sendMessage(text);
    _controller.clear();
  }

  void _handleSearchChange() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _isListening = false);
          showMessage('Voice input error: ${error.errorMsg}');
        },
      );
      if (!mounted) return;
      setState(() => _speechAvailable = available);
    } catch (_) {
      if (!mounted) return;
      setState(() => _speechAvailable = false);
    }
  }

  Future<void> _initTts() async {
    try {
      bool hasEngine = true;
      try {
        final engines = await _tts.getEngines;
        if (engines is List && engines.isEmpty) {
          hasEngine = false;
        }
        if (engines is List) {
          _ttsInfo = 'Engines: ${engines.length}';
        }
      } catch (_) {}

      if (!hasEngine) {
        if (mounted) {
          setState(() => _ttsReady = false);
        }
        showMessage('Install a text-to-speech engine to enable voice output.');
        return;
      }

      final languages = await _tts.getLanguages;
      String? language;
      if (languages is List && languages.isNotEmpty) {
        _ttsInfo = '${_ttsInfo ?? ''} Languages: ${languages.length}'.trim();
        if (languages.contains('en-US')) {
          language = 'en-US';
        } else if (languages.contains('en')) {
          language = 'en';
        } else {
          language = languages.first.toString();
        }
      }
      if (language != null && language.isNotEmpty) {
        await _tts.setLanguage(language);
      }
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.35);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingMessageIndex = null;
          _speakingStart = -1;
          _speakingEnd = -1;
          _speakingText = null;
          _speakingCursor = 0;
          _speakingCursorText = null;
        });
      });
      _tts.setCancelHandler(() {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingMessageIndex = null;
          _speakingStart = -1;
          _speakingEnd = -1;
          _speakingText = null;
          _speakingCursor = 0;
          _speakingCursorText = null;
        });
      });
      _tts.setErrorHandler((_) {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _speakingMessageIndex = null;
          _speakingStart = -1;
          _speakingEnd = -1;
          _speakingText = null;
          _speakingCursor = 0;
          _speakingCursorText = null;
        });
      });
      _tts.setProgressHandler((text, start, end, word) {
        if (!mounted || !_isSpeaking) return;
        final baseText = _speakingCursorText ?? text;
        final range = _resolveSpeechRange(baseText, text, start, end, word);
        if (range == null) return;
        setState(() {
          _speakingText = baseText;
          _speakingStart = range.start;
          _speakingEnd = range.end;
        });
      });
      if (mounted) {
        setState(() => _ttsReady = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _ttsReady = false);
      }
    }
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }
    if (!_speechAvailable) {
      await _initSpeech();
    }
    if (!_speechAvailable) {
      showMessage('Enable microphone permission to use voice input.');
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        _controller.text = result.recognizedWords;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(partialResults: true),
    );
  }

  void _startNewChat() {
    presenter.resetConversation();
    _controller.clear();
    _chatSearchController.clear();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _confirmDeleteChat(AiConversation conversation) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete chat?', 'च्याट मेटाउने?')),
        content: Text(
          context.tr(
            'Delete "${conversation.title}"? This cannot be undone.',
            '"${conversation.title}" हटाउने? यो फिर्ता हुँदैन।',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel', 'रद्द गर्नुहोस्')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Delete', 'मेटाउनुहोस्')),
          ),
        ],
      ),
    );
    if (result == true) {
      final currentLast = presenter.state.value.messages.isNotEmpty
          ? presenter.state.value.messages.last.text
          : null;
      if (currentLast != null) {
        _lastAutoSpoken = currentLast;
      }
      await _stopSpeaking();
      await presenter.deleteConversation(conversation.id);
      if (mounted &&
          conversation.id == presenter.state.value.activeConversationId) {
        _lastAutoSpoken = null;
      }
    }
  }

  Future<void> _confirmDeleteAllChats() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete all chats?', 'सबै च्याट मेटाउने?')),
        content: Text(
          context.tr(
            'This will remove all your AI conversations. This cannot be undone.',
            'यसले तपाईंका सबै एआई च्याटहरू हटाउनेछ। यो फिर्ता हुँदैन।',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel', 'रद्द गर्नुहोस्')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Delete all', 'सबै मेटाउनुहोस्')),
          ),
        ],
      ),
    );
    if (result == true) {
      final currentLast = presenter.state.value.messages.isNotEmpty
          ? presenter.state.value.messages.last.text
          : null;
      if (currentLast != null) {
        _lastAutoSpoken = currentLast;
      }
      await _stopSpeaking();
      await presenter.deleteAllConversations();
      if (mounted) {
        _lastAutoSpoken = null;
      }
    }
  }

  Future<void> _speak(String text, {int? messageIndex}) async {
    if (text.trim().isEmpty) return;
    if (!_isScreenActive()) return;
    if (!_ttsReady) {
      await _initTts();
    }
    if (!_ttsReady) {
      final info = _ttsInfo == null ? '' : ' ($_ttsInfo)';
      showMessage(
          'Text-to-speech unavailable.$info Tap the settings icon to enable TTS.');
      return;
    }
    if (_isSpeaking) {
      await _tts.stop();
    }
    setState(() {
      _isSpeaking = true;
      _speakingMessageIndex = messageIndex;
      _speakingText = text;
      _speakingStart = -1;
      _speakingEnd = -1;
      _speakingCursor = 0;
      _speakingCursorText = text;
    });
    final result = await _tts.speak(text);
    if (result != null && result is int && result == 0) {
      setState(() => _isSpeaking = false);
      showMessage('Voice output failed. Check system TTS settings.');
    }
  }

  Future<void> _openTtsSettings() async {
    try {
      if (Platform.isAndroid) {
        const intent = AndroidIntent(
          action: 'android.settings.TTS_SETTINGS',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
        return;
      }
      if (Platform.isIOS) {
        await AppSettings.openAppSettings();
        return;
      }
    } catch (_) {}
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.sound);
      return;
    } catch (_) {}
    showMessage('Open device settings to enable Text-to-Speech.');
  }

  Future<void> _toggleAutoSpeak() async {
    setState(() => _autoSpeak = !_autoSpeak);
    if (!_autoSpeak && _isSpeaking) {
      await _tts.stop();
      if (mounted) {
        setState(() => _isSpeaking = false);
      }
    }
  }

  bool _isScreenActive() {
    if (!mounted) return false;
    final offstage =
        context.findAncestorWidgetOfExactType<Offstage>()?.offstage ?? false;
    if (offstage) return false;
    if (!TickerMode.valuesOf(context).enabled) return false;
    return true;
  }

  Future<void> _stopSpeaking() async {
    if (!_isSpeaking) return;
    await _tts.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
        _speakingMessageIndex = null;
        _speakingStart = -1;
        _speakingEnd = -1;
        _speakingText = null;
        _speakingCursor = 0;
        _speakingCursorText = null;
      });
    }
  }

  _HighlightRange? _resolveSpeechRange(
    String baseText,
    String rawText,
    int start,
    int end,
    String? word,
  ) {
    final token = (word ?? '').trim();
    if (token.isNotEmpty) {
      final lowerBase = baseText.toLowerCase();
      final lowerWord = token.toLowerCase();
      var index = lowerBase.indexOf(lowerWord, _speakingCursor);
      if (index < 0) {
        index = lowerBase.indexOf(lowerWord);
      }
      if (index >= 0) {
        _speakingCursor = index + lowerWord.length;
        return _HighlightRange(index, index + lowerWord.length);
      }
    }
    if (rawText == baseText &&
        start >= 0 &&
        end > start &&
        end <= baseText.length) {
      return _HighlightRange(start, end);
    }
    return null;
  }

  void _showAllChats(List<AiConversation> chats, String? activeId) {
    if (chats.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1220),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Your chats', 'तपाईंका च्याटहरू'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final conversation = chats[index];
                      return _AiChatRow(
                        conversation: conversation,
                        isActive: conversation.id == activeId,
                        onTap: () {
                          Navigator.of(context).pop();
                          presenter.openConversation(conversation.id);
                        },
                        onDelete: () => _confirmDeleteChat(conversation),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.78;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        title: AnimatedOpacity(
          opacity: _showTitle ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            context.tr('AI Study Assistant', 'एआई अध्ययन सहायक'),
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
      body: ValueListenableBuilder<AiViewModel>(
        valueListenable: presenter.state,
        builder: (context, model, _) {
          final hasMessages = model.messages.isNotEmpty;
          final screenActive = _isScreenActive();
          if (!screenActive && _isSpeaking) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _stopSpeaking();
              }
            });
          }
          final filteredChats = _filterConversations(
            model.conversations,
            _chatSearchController.text,
          );
          if (_autoSpeak && screenActive && model.messages.isNotEmpty) {
            final last = model.messages.last;
            if (!last.isUser && last.text.trim().isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_autoSpeak) return;
                if (!_isScreenActive()) return;
                if (last.text == _lastAutoSpoken) return;
                _lastAutoSpoken = last.text;
                _speak(last.text,
                    messageIndex: model.messages.length - 1);
              });
            }
          } else if (!screenActive && model.messages.isNotEmpty) {
            _lastAutoSpoken = model.messages.last.text;
          }
          return Stack(
            children: [
              const Positioned.fill(child: _AiBackdrop()),
              Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                        20,
                        MediaQuery.of(context).padding.top +
                            kToolbarHeight -
                            44,
                        20,
                        28,
                      ),
                      children: [
                        _AiHeroCard(hasMessages: hasMessages),
                        const SizedBox(height: 12),
                        const AiStatusChip(),
                        const SizedBox(height: 20),
                        _AiSidebarCard(
                          onNewChat: _startNewChat,
                          conversations: filteredChats,
                          activeId: model.activeConversationId,
                          onSelect: (conversation) {
                            presenter.openConversation(conversation.id);
                          },
                          expanded: _chatsExpanded,
                          onToggle: () {
                            setState(() => _chatsExpanded = !_chatsExpanded);
                          },
                          searchController: _chatSearchController,
                          searchFocus: _chatSearchFocus,
                          hasQuery:
                              _chatSearchController.text.trim().isNotEmpty,
                          onSearchChanged: (_) => _handleSearchChange(),
                          onViewAll: model.conversations.length > 4
                              ? () => _showAllChats(
                                    model.conversations,
                                    model.activeConversationId,
                                  )
                              : null,
                          onDelete: _confirmDeleteChat,
                          onDeleteAll: model.conversations.isNotEmpty
                              ? _confirmDeleteAllChats
                              : null,
                        ),
                        const SizedBox(height: 16),
                        if (hasMessages) ...[
                          ...model.messages.asMap().entries.map(
                            (entry) => _ChatBubble(
                              message: entry.value,
                              highlightStart: _speakingMessageIndex == entry.key
                                  ? _speakingStart
                                  : null,
                              highlightEnd: _speakingMessageIndex == entry.key
                                  ? _speakingEnd
                                  : null,
                              highlightText: _speakingMessageIndex == entry.key
                                  ? _speakingText
                                  : null,
                              maxWidth: maxBubbleWidth,
                              onSpeak: entry.value.isUser
                                  ? null
                                  : () => _speak(
                                        entry.value.text,
                                        messageIndex: entry.key,
                                      ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 16),
                          const _AiEmptyState(),
                        ],
                        const SizedBox(height: 16),
                        if (model.errorMessage != null)
                          _GameCard(
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Color(0xFFF87171)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    model.errorMessage!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: const Color(0xFFF87171)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        _SuggestionSection(
                          suggestions: model.suggestions,
                          onSelect: (suggestion) {
                            _controller.text = '${suggestion.trim()}: ';
                            _controller.selection = TextSelection.fromPosition(
                              TextPosition(offset: _controller.text.length),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0B1220),
                      border: Border(
                        top: BorderSide(color: Color(0xFF1E2A44)),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF1E2A44)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _InputIconButton(
                              icon: _autoSpeak
                                  ? Icons.volume_up
                                  : Icons.volume_off,
                              onPressed: _toggleAutoSpeak,
                            ),
                            const SizedBox(width: 4),
                            _InputIconButton(
                              icon: Icons.settings_voice,
                              onPressed: _openTtsSettings,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                constraints:
                                    const BoxConstraints(minHeight: 44),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF111827),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF1E2A44),
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _inputFocus,
                                    minLines: 1,
                                    maxLines: 3,
                                    textAlignVertical:
                                        TextAlignVertical.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          EdgeInsets.symmetric(vertical: 10),
                                      hintText: context.tr(
                                        'Ask a question…',
                                        'प्रश्न सोध्नुहोस्…',
                                      ),
                                      hintMaxLines: 1,
                                      hintStyle: const TextStyle(
                                        color: Colors.white60,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      border: InputBorder.none,
                                      filled: false,
                                    ),
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            _InputIconButton(
                              icon: _isListening ? Icons.mic : Icons.mic_none,
                              backgroundColor: _isListening
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF111B2E),
                              onPressed: _toggleListening,
                            ),
                            const SizedBox(width: 4),
                            _InputIconButton(
                              icon: Icons.send,
                              backgroundColor: const Color(0xFF38BDF8),
                              onPressed:
                                  model.isLoading ? null : _sendMessage,
                              child: model.isLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  List<AiConversation> _filterConversations(
    List<AiConversation> conversations,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return conversations;
    final scored = <(AiConversation, int)>[];
    for (final conversation in conversations) {
      final score =
          _fuzzyScore(normalized, conversation.title.toLowerCase());
      if (score > 0) {
        scored.add((conversation, score));
      }
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.map((entry) => entry.$1).toList();
  }

  int _fuzzyScore(String query, String title) {
    if (title.contains(query)) {
      return 120 - title.indexOf(query);
    }
    if (_isSubsequence(query, title)) {
      return 80 - (title.length - query.length);
    }
    final maxDistance = (query.length * 0.5).round().clamp(2, 6);
    var best = _levenshtein(query, title);
    for (final word in title.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final dist = _levenshtein(query, word);
      if (dist < best) best = dist;
    }
    if (best <= maxDistance) {
      return 60 - (best * 6);
    }
    return 0;
  }

  bool _isSubsequence(String query, String text) {
    var qi = 0;
    for (var ti = 0; ti < text.length && qi < query.length; ti += 1) {
      if (text[ti] == query[qi]) {
        qi += 1;
      }
    }
    return qi == query.length;
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    final prev = List<int>.generate(t.length + 1, (i) => i);
    final curr = List<int>.filled(t.length + 1, 0);
    for (var i = 1; i <= s.length; i += 1) {
      curr[0] = i;
      for (var j = 1; j <= t.length; j += 1) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        curr[j] = [
          curr[j - 1] + 1,
          prev[j] + 1,
          prev[j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
      for (var j = 0; j <= t.length; j += 1) {
        prev[j] = curr[j];
      }
    }
    return prev[t.length];
  }

}

class _AiHeroCard extends StatelessWidget {
  final bool hasMessages;

  const _AiHeroCard({required this.hasMessages});

  @override
  Widget build(BuildContext context) {
    return _GameCard(
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
            child: const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFF38BDF8)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasMessages
                      ? context.tr('Keep learning', 'सिकाइ जारी राख्नुहोस्')
                      : context.tr('AI Study Assistant', 'एआई अध्ययन सहायक'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasMessages
                      ? context.tr(
                          'Ask follow-ups, request summaries, or get practice questions.',
                          'थप प्रश्न सोध्नुहोस्, सारांश माग्नुहोस् वा अभ्यास प्रश्न पाउनुहोस्।',
                        )
                      : context.tr(
                          'Ask for explanations, summaries, or quiz questions.',
                          'व्याख्या, सारांश वा क्विज प्रश्न माग्नुहोस्।',
                        ),
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
    );
  }
}

class _AiSidebarCard extends StatelessWidget {
  final VoidCallback onNewChat;
  final List<AiConversation> conversations;
  final String? activeId;
  final ValueChanged<AiConversation> onSelect;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onViewAll;
  final ValueChanged<AiConversation>? onDelete;
  final VoidCallback? onDeleteAll;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool hasQuery;
  final ValueChanged<String> onSearchChanged;

  const _AiSidebarCard({
    required this.onNewChat,
    required this.conversations,
    required this.activeId,
    required this.onSelect,
    required this.expanded,
    required this.onToggle,
    required this.searchController,
    required this.searchFocus,
    required this.hasQuery,
    required this.onSearchChanged,
    this.onViewAll,
    this.onDelete,
    this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onNewChat,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111B2E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1E2A44)),
                    ),
                    child: const Icon(Icons.edit_outlined,
                        color: Color(0xFF38BDF8)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.tr('New chat', 'नयाँ च्याट'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Colors.white54, size: 18),
                ],
              ),
            ),
          ),
          const Divider(
            height: 20,
            thickness: 1,
            color: Color(0xFF1E2A44),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    context.tr('Your chats', 'तपाईंका च्याटहरू'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: Colors.white70),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white60,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF111B2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E2A44)),
              ),
              child: TextField(
                controller: searchController,
                focusNode: searchFocus,
                style: const TextStyle(color: Colors.white),
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                  hintText: context.tr('Search chats', 'च्याट खोज्नुहोस्'),
                  hintStyle: const TextStyle(color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final visibleChats =
                    hasQuery ? conversations : conversations.take(4).toList();
                if (visibleChats.isEmpty) {
                  return Text(
                    hasQuery
                        ? context.tr(
                            'No chats found for that search.',
                            'त्यो खोजका लागि च्याट भेटिएन।',
                          )
                        : context.tr(
                            'No chats yet. Start a new one.',
                            'अहिले कुनै च्याट छैन। नयाँ सुरु गर्नुहोस्।',
                          ),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white54),
                  );
                }
                return Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: visibleChats.length > 2 ? 180 : 96,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            ...visibleChats.map(
                              (conversation) => _AiChatRow(
                                conversation: conversation,
                                isActive: conversation.id == activeId,
                                onTap: () => onSelect(conversation),
                                onDelete: onDelete == null
                                    ? null
                                    : () => onDelete!(conversation),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (onDeleteAll != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onDeleteAll,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFF87171),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(
                            context.tr(
                              'Delete all chats',
                              'सबै च्याट मेटाउनुहोस्',
                            ),
                          ),
                        ),
                      ),
                    if (!hasQuery && onViewAll != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: onViewAll,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                          ),
                          child: Text(
                            context.tr('View all chats', 'सबै च्याट हेर्नुहोस्'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AiChatRow extends StatelessWidget {
  final AiConversation conversation;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _AiChatRow({
    required this.conversation,
    required this.isActive,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF111B2E) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? const Color(0xFF38BDF8) : const Color(0xFF1E2A44),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      color: Colors.white54, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: context.tr('Delete', 'मेटाउनुहोस्'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiEmptyState extends StatelessWidget {
  const _AiEmptyState();

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Start with a question', 'प्रश्नबाट सुरु गर्नुहोस्'),
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
            context.tr(
              'Try asking for a short summary, key formulas, or a practice quiz.',
              'छोटो सारांश, मुख्य सूत्र वा अभ्यास क्विज माग्नुहोस्।',
            ),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InlineTag(
                  label:
                      context.tr('Explain concept', 'अवधारणा व्याख्या गर्नुहोस्')),
              _InlineTag(
                  label: context.tr('Summarize notes', 'नोटहरू सारांश')),
              _InlineTag(label: context.tr('Generate MCQs', 'MCQ बनाउनुहोस्')),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineTag extends StatelessWidget {
  final String label;

  const _InlineTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF111B2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: const Color(0xFF38BDF8)),
      ),
    );
  }
}

class _SuggestionSection extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSelect;

  const _SuggestionSection({
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Try asking', 'यसरी सोध्नुहोस्'),
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions
              .map(
                (suggestion) => ActionChip(
                  label: Text(suggestion),
                  backgroundColor: const Color(0xFF0B1220),
                  side: const BorderSide(color: Color(0xFF1E2A44)),
                  labelStyle: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: Colors.white70),
                  onPressed: () => onSelect(suggestion),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final AiMessage message;
  final double maxWidth;
  final VoidCallback? onSpeak;
  final int? highlightStart;
  final int? highlightEnd;
  final String? highlightText;

  const _ChatBubble({
    required this.message,
    required this.maxWidth,
    this.onSpeak,
    this.highlightStart,
    this.highlightEnd,
    this.highlightText,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final highlight = _resolveHighlight();
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF2563EB) : const Color(0xFF0B1220),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 18),
          ),
          border:
              isUser ? null : Border.all(color: const Color(0xFF1E2A44)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUser
                      ? context.tr('You', 'तपाईं')
                      : context.tr('AI Assistant', 'एआई सहायक'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isUser ? Colors.white70 : Colors.white60,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (!isUser && onSpeak != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onSpeak,
                    child: const Icon(
                      Icons.volume_up,
                      size: 16,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            highlight == null
                ? Text(
                    message.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                        ),
                  )
                : RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                          ),
                      children: [
                        if (highlight.start > 0)
                          TextSpan(
                            text: message.text.substring(0, highlight.start),
                          ),
                        TextSpan(
                          text: message.text.substring(
                            highlight.start,
                            highlight.end,
                          ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black,
                              backgroundColor:
                                  const Color(0xFFFFD54F).withValues(alpha: 0.65),
                              fontWeight: FontWeight.w600,
                            ),
                        ),
                        if (highlight.end < message.text.length)
                          TextSpan(
                            text: message.text.substring(highlight.end),
                          ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  _HighlightRange? _resolveHighlight() {
    if (highlightStart == null || highlightEnd == null) return null;
    if (highlightText == null || highlightText!.isEmpty) return null;
    var start = highlightStart!;
    var end = highlightEnd!;
    if (end <= start) return null;
    if (highlightText != message.text) {
      final index = highlightText!.indexOf(message.text);
      if (index < 0) return null;
      start = start - index;
      end = end - index;
    }
    if (start < 0 || end > message.text.length) return null;
    return _HighlightRange(start, end);
  }
}

class _HighlightRange {
  final int start;
  final int end;

  const _HighlightRange(this.start, this.end);
}

class _AiBackdrop extends StatelessWidget {
  const _AiBackdrop();

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
          Positioned.fill(child: CustomPaint(painter: _AiGridPainter())),
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

class _AiGridPainter extends CustomPainter {
  const _AiGridPainter();

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
  bool shouldRepaint(covariant _AiGridPainter oldDelegate) => false;
}

class _InputIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Widget? child;

  const _InputIconButton({
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final bg = backgroundColor ?? const Color(0xFF111B2E);
    return SizedBox(
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E2A44)),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Center(
              child: child ??
                  Icon(
                    icon,
                    size: 18,
                    color: enabled ? Colors.white : Colors.white38,
                  ),
            ),
          ),
        ),
      ),
    );
  }
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
