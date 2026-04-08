import 'package:flutter/material.dart';
import 'package:student_survivor/data/app_state.dart';

class FocusOverlayBar extends StatelessWidget {
  const FocusOverlayBar({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Duration>(
      valueListenable: AppState.focusRemaining,
      builder: (context, remaining, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: AppState.focusInBreak,
          builder: (context, inBreak, child) {
            return ValueListenableBuilder<bool>(
              valueListenable: AppState.focusRunning,
              builder: (context, running, child) {
                final minutes =
                    remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
                final seconds =
                    remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
                final hours =
                    remaining.inHours > 0 ? '${remaining.inHours}:' : '';
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 128),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1220),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1E2A44)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          running
                              ? (inBreak ? Icons.coffee : Icons.timer)
                              : Icons.pause_circle_filled,
                          color: running
                              ? (inBreak
                                  ? const Color(0xFFF59E0B)
                                  : Colors.white)
                              : Colors.white70,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$hours$minutes:$seconds',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: AppState.endFocusLock,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 2),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
