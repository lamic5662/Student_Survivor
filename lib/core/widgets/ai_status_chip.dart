import 'package:flutter/material.dart';
import 'package:student_survivor/data/supabase_config.dart';

class AiStatusChip extends StatelessWidget {
  final bool compact;

  const AiStatusChip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: SupabaseConfig.aiProviderNotifier,
      builder: (context, provider, _) {
        return _AiChipBody(label: _aiStatusLabel(provider));
      },
    );
  }

  String _aiStatusLabel(String? activeProvider) {
    final active = activeProvider?.toLowerCase();
    if (active != null && active.isNotEmpty) {
      return compact
          ? 'AI: ${_providerName(active)}'
          : 'AI: ${_providerName(active)} (active)';
    }
    final selected =
        (SupabaseConfig.aiProviderOverride ?? SupabaseConfig.aiMode)
            .toLowerCase();
    if (selected == 'cloud' || selected == 'auto' || selected == 'free') {
      return compact
          ? 'AI: Auto'
          : 'AI: Auto (Groq → OpenRouter → Gemini → Ollama)';
    }
    return 'AI: ${_providerName(selected)}';
  }

  String _providerName(String provider) {
    switch (provider) {
      case 'groq':
        return 'Groq';
      case 'openrouter':
        return 'OpenRouter';
      case 'gemini':
        return 'Gemini';
      case 'ollama':
        return 'Ollama';
      case 'lmstudio':
      case 'lm-studio':
      case 'lm_studio':
        return 'LM Studio';
      case 'backend':
        return 'Backend';
      default:
        return provider.isEmpty ? 'Auto' : provider;
    }
  }
}

class _AiChipBody extends StatelessWidget {
  final String label;

  const _AiChipBody({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E2A44)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF38BDF8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
