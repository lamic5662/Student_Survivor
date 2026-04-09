import 'package:flutter/material.dart';
import 'package:student_survivor/core/localization/app_localizations.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
import 'package:student_survivor/core/widgets/math_text.dart';
import 'package:student_survivor/data/community_qna_service.dart';
import 'package:student_survivor/data/supabase_config.dart';
import 'package:student_survivor/models/app_models.dart';

class SubjectQnaScreen extends StatefulWidget {
  final Subject subject;

  const SubjectQnaScreen({
    super.key,
    required this.subject,
  });

  @override
  State<SubjectQnaScreen> createState() => _SubjectQnaScreenState();
}

class _SubjectQnaScreenState extends State<SubjectQnaScreen> {
  late final CommunityQnaService _service;
  final _questionController = TextEditingController();
  List<CommunityQuestion> _questions = const [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  String? get _userId => SupabaseConfig.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _service = CommunityQnaService(SupabaseConfig.client);
    _load();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final questions = await _service.fetchQuestionsForSubject(
        widget.subject.id,
      );
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = context.tr(
          'Failed to load questions: $error',
          'प्रश्न लोड गर्न असफल: $error',
        );
        _loading = false;
      });
    }
  }

  Future<void> _submitQuestion() async {
    final text = _questionController.text.trim();
    if (text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Please add a clearer question.',
              'कृपया स्पष्ट प्रश्न लेख्नुहोस्।',
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _submitting = true;
    });
    try {
      final question = await _service.submitQuestion(
        subject: widget.subject,
        question: text,
      );
      if (!mounted) return;
      _questionController.clear();
      setState(() {
        _questions = [question, ..._questions];
      });
      final message = question.status == 'approved'
          ? context.tr('Question published!', 'प्रश्न प्रकाशित भयो!')
          : context.tr('Submitted for admin review.', 'एडमिन समीक्षाका लागि पठाइयो।');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Failed to submit: $error', 'पेश गर्न असफल: $error'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _openAnswers(CommunityQuestion question) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AnswerSheet(
        question: question,
        service: _service,
        currentUserId: _userId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            '${widget.subject.name} Q&A',
            '${widget.subject.name} प्रश्नोत्तर',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1220),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E2A44)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Ask a question', 'प्रश्न सोध्नुहोस्'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'AI checks relevance. If not verified, admin reviews it.',
                    'AI ले सान्दर्भिकता जाँच्छ। पुष्टि नभए एडमिनले समीक्षा गर्छ।',
                  ),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _questionController,
                  maxLines: 3,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: context.tr(
                      'Type your question...',
                      'आफ्नो प्रश्न लेख्नुहोस्...',
                    ),
                    hintStyle: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF111B2E),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF1E2A44)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF1E2A44)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF4FA3C7)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4FA3C7),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _submitting
                          ? context.tr('Submitting...', 'पेश हुँदैछ...')
                          : context.tr('Submit Question', 'प्रश्न पेश गर्नुहोस्'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                context.tr('Public Questions', 'सार्वजनिक प्रश्नहरू'),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: context.tr('Refresh', 'रिफ्रेस'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(
              _error!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.danger),
            )
          else if (_questions.isEmpty)
            Text(
              context.tr(
                'No questions yet. Be the first to ask!',
                'अहिलेसम्म प्रश्न छैन। पहिलो बन्नुहोस्!',
              ),
            )
          else
            ..._questions.map(
              (question) {
                final isMine = question.userId == _userId;
                final isApproved = question.status == 'approved';
                final statusLabel = isApproved
                    ? context.tr('Published', 'प्रकाशित')
                    : context.tr('Pending review', 'समीक्षा प्रतिक्षा');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1220),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF1E2A44)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: IconTheme.merge(
                      data: const IconThemeData(color: Colors.white),
                      child: DefaultTextStyle.merge(
                        style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white) ??
                            const TextStyle(color: Colors.white),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: MathText(
                                    text: question.question,
                                    textStyle: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isApproved
                                        ? const Color(0xFF0F2E22)
                                        : const Color(0xFF3A2C00),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: isApproved
                                              ? const Color(0xFF34D399)
                                              : const Color(0xFFFBBF24),
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              [
                                question.userName ??
                                    (isMine
                                        ? context.tr('You', 'तपाईं')
                                        : context.tr('Student', 'विद्यार्थी')),
                                if ((question.collegeName ?? '').isNotEmpty)
                                  question.collegeName!,
                              ].join(' • '),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.white70),
                            ),
                            if (isMine) ...[
                              const SizedBox(height: 6),
                              Text(
                                context.tr(
                                  'You asked this question',
                                  'तपाईंले यो प्रश्न सोध्नुभएको थियो',
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                            if (!isApproved &&
                                (question.aiReason ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              MathText(
                                text: 'AI: ${question.aiReason}',
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.white70),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: isApproved
                                    ? () => _openAnswers(question)
                                    : null,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.forum_outlined),
                                label: Text(
                                  isApproved
                                      ? context.tr(
                                          'View answers',
                                          'उत्तरहरू हेर्नुहोस्',
                                        )
                                      : context.tr(
                                          'Awaiting review',
                                          'समीक्षाको प्रतीक्षा',
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _AnswerSheet extends StatefulWidget {
  final CommunityQuestion question;
  final CommunityQnaService service;
  final String? currentUserId;

  const _AnswerSheet({
    required this.question,
    required this.service,
    required this.currentUserId,
  });

  @override
  State<_AnswerSheet> createState() => _AnswerSheetState();
}

class _AnswerSheetState extends State<_AnswerSheet> {
  final _answerController = TextEditingController();
  List<CommunityAnswer> _answers = const [];
  bool _loading = true;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });
    final answers = await widget.service.fetchAnswers(widget.question.id);
    if (!mounted) return;
    setState(() {
      _answers = answers;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    final text = _answerController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _posting = true;
    });
    try {
      await widget.service.addAnswer(
        questionId: widget.question.id,
        answer: text,
      );
      _answerController.clear();
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Failed to post: $error', 'पोस्ट गर्न असफल: $error'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _posting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = widget.question.status == 'approved';
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MathText(
            text: widget.question.question,
            textStyle: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_answers.isEmpty)
            Text(context.tr('No answers yet.', 'अहिलेसम्म उत्तर छैन।'))
          else
            ..._answers.map(
              (answer) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          answer.userName ??
                              context.tr('Student', 'विद्यार्थी'),
                          if ((answer.collegeName ?? '').isNotEmpty)
                            answer.collegeName!,
                        ].join(' • '),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.mutedInk),
                      ),
                      const SizedBox(height: 6),
                      MathText(text: answer.answer),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (!isApproved)
            Text(
              context.tr(
                'This question is still pending review.',
                'यो प्रश्न अझै समीक्षा प्रक्रियामा छ।',
              ),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedInk),
            )
          else ...[
            TextField(
              controller: _answerController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText:
                    context.tr('Write your answer...', 'आफ्नो उत्तर लेख्नुहोस्...'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _posting ? null : _submit,
                child: Text(
                  _posting
                      ? context.tr('Posting...', 'पोस्ट हुँदैछ...')
                      : context.tr('Post Answer', 'उत्तर पोस्ट गर्नुहोस्'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
