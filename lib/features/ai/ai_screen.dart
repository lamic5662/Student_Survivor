import 'package:flutter/material.dart';
import 'package:student_survivor/core/mvp/presenter_state.dart';
import 'package:student_survivor/features/ai/ai_presenter.dart';
import 'package:student_survivor/features/ai/ai_view_model.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState
    extends PresenterState<AiAssistantScreen, AiView, AiPresenter>
    implements AiView {
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showTitle = true;

  @override
  AiPresenter createPresenter() => AiPresenter();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
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
            'AI Study Assistant',
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
                            kToolbarHeight +
                            -44,
                        20,
                        20,
                      ),
                      children: [
                        _AiHeroCard(hasMessages: hasMessages),
                        if (hasMessages) ...[
                          const SizedBox(height: 16),
                          ...model.messages.map(
                            (message) => _ChatBubble(
                              message: message,
                              maxWidth: maxBubbleWidth,
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
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111B2E),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF1E2A44),
                                ),
                              ),
                              child: TextField(
                                controller: _controller,
                                minLines: 1,
                                maxLines: 4,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Ask anything about your subject...',
                                  hintStyle:
                                      TextStyle(color: Colors.white54),
                                  border: InputBorder.none,
                                  filled: false,
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF38BDF8),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: model.isLoading ? null : _sendMessage,
                            icon: model.isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
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
                  hasMessages ? 'Keep learning' : 'AI Study Assistant',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  hasMessages
                      ? 'Ask follow-ups, request summaries, or get practice questions.'
                      : 'Ask for explanations, summaries, or quiz questions.',
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

class _AiEmptyState extends StatelessWidget {
  const _AiEmptyState();

  @override
  Widget build(BuildContext context) {
    return _GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start with a question',
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
            'Try asking for a short summary, key formulas, or a practice quiz.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _InlineTag(label: 'Explain concept'),
              _InlineTag(label: 'Summarize notes'),
              _InlineTag(label: 'Generate MCQs'),
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
          'Try asking',
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

  const _ChatBubble({
    required this.message,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
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
            Text(
              isUser ? 'You' : 'AI Assistant',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isUser ? Colors.white70 : Colors.white60,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ],
        ),
      ),
    );
  }
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
