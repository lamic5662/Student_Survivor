class AiUsage {
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  const AiUsage({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  Map<String, dynamic> toJson() => {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
      };

  static AiUsage? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return AiUsage(
      promptTokens: _asInt(json['prompt_tokens']),
      completionTokens: _asInt(json['completion_tokens']),
      totalTokens: _asInt(json['total_tokens']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class AiResponse {
  final String content;
  final String provider;
  final String? model;
  final AiUsage? usage;

  const AiResponse({
    required this.content,
    required this.provider,
    this.model,
    this.usage,
  });

  AiResponse copyWith({
    String? content,
    String? provider,
    String? model,
    AiUsage? usage,
  }) {
    return AiResponse(
      content: content ?? this.content,
      provider: provider ?? this.provider,
      model: model ?? this.model,
      usage: usage ?? this.usage,
    );
  }
}
