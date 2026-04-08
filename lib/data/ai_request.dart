import 'package:student_survivor/data/supabase_config.dart';

class AiRequest {
  final AiFeature feature;
  final String systemPrompt;
  final String userPrompt;
  final double temperature;
  final bool fastModel;
  final Duration? timeout;
  final Map<String, dynamic>? metadata;
  final bool expectsJson;

  const AiRequest({
    required this.feature,
    required this.systemPrompt,
    required this.userPrompt,
    this.temperature = 0.3,
    this.fastModel = false,
    this.timeout,
    this.metadata,
    this.expectsJson = false,
  });
}
