import 'package:flutter/material.dart';
import 'package:student_survivor/core/theme/app_theme.dart';
import 'package:student_survivor/core/widgets/app_card.dart';
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
        _error = 'Failed to load questions: $error';
        _loading = false;
      });
    }
  }

  Future<void> _submitQuestion() async {
    final text = _questionController.text.trim();
    if (text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a clearer question.')),
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
          ? 'Question published!'
          : 'Submitted for admin review.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $error')),
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
        title: Text('${widget.subject.name} Q&A'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask a question',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI checks relevance. If not verified, admin reviews it.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _questionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Type your question...',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submitQuestion,
                    child:
                        Text(_submitting ? 'Submitting...' : 'Submit Question'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Public Questions',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
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
            const Text('No questions yet. Be the first to ask!')
          else
            ..._questions.map(
              (question) {
                final isMine = question.userId == _userId;
                final isApproved = question.status == 'approved';
                final statusLabel =
                    isApproved ? 'Published' : 'Pending review';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                question.question,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isApproved
                                    ? AppColors.success.withValues(alpha: 0.12)
                                    : AppColors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: isApproved
                                          ? AppColors.success
                                          : AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        if (isMine) ...[
                          const SizedBox(height: 6),
                          Text(
                            'You asked this question',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.mutedInk),
                          ),
                        ],
                        if (!isApproved &&
                            (question.aiReason ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'AI: ${question.aiReason}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.mutedInk),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed:
                                isApproved ? () => _openAnswers(question) : null,
                            icon: const Icon(Icons.forum_outlined),
                            label: Text(
                              isApproved ? 'View answers' : 'Awaiting review',
                            ),
                          ),
                        ),
                      ],
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
        SnackBar(content: Text('Failed to post: $error')),
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
          Text(
            widget.question.question,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_answers.isEmpty)
            const Text('No answers yet.')
          else
            ..._answers.map(
              (answer) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Text(answer.answer),
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (!isApproved)
            Text(
              'This question is still pending review.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.mutedInk),
            )
          else ...[
            TextField(
              controller: _answerController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Write your answer...',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _posting ? null : _submit,
                child: Text(_posting ? 'Posting...' : 'Post Answer'),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
