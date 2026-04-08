import 'dart:async';

import 'package:flutter/material.dart';
import 'package:student_survivor/data/local_ai_status_service.dart';

class LocalAiStatusStrip extends StatefulWidget {
  final bool compact;
  final Duration refreshInterval;
  final Duration timeout;

  const LocalAiStatusStrip({
    super.key,
    this.compact = false,
    this.refreshInterval = const Duration(seconds: 25),
    this.timeout = const Duration(seconds: 2),
  });

  @override
  State<LocalAiStatusStrip> createState() => _LocalAiStatusStripState();
}

class _LocalAiStatusStripState extends State<LocalAiStatusStrip> {
  LocalAiStatus? _status;
  late final LocalAiStatusService _service =
      LocalAiStatusService(timeout: widget.timeout);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    if (widget.refreshInterval.inSeconds > 0) {
      _timer =
          Timer.periodic(widget.refreshInterval, (_) => _refresh(silent: true));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    try {
      final status = await _service.fetch();
      if (!mounted) return;
      setState(() => _status = status);
    } catch (_) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to check local AI status.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Container(
      padding: EdgeInsets.fromLTRB(12, widget.compact ? 8 : 10, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.compact ? 'Local' : 'Local AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: Icon(Icons.refresh, size: widget.compact ? 16 : 18),
                color: Colors.white54,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: widget.compact ? 24 : 28,
                  minHeight: widget.compact ? 24 : 28,
                ),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (status == null)
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Checking local AI...',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white70),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusPill(
                  context,
                  label: 'Ollama',
                  online: status.ollamaOnline,
                  latency: status.ollamaLatency,
                  compact: widget.compact,
                ),
                _statusPill(
                  context,
                  label: 'LM Studio',
                  online: status.lmStudioOnline,
                  latency: status.lmStudioLatency,
                  compact: widget.compact,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _statusPill(
    BuildContext context, {
    required String label,
    required bool online,
    Duration? latency,
    required bool compact,
  }) {
    final dotColor = online ? const Color(0xFF22C55E) : const Color(0xFF94A3B8);
    final shortLabel = label.toLowerCase().contains('lm') ? 'LM' : 'Ol';
    final text = compact
        ? shortLabel
        : online
            ? latency == null
                ? '$label • Online'
                : '$label • ${latency.inMilliseconds} ms'
            : '$label • Offline';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2A44)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 8,
            height: compact ? 6 : 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 4 : 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
