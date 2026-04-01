class BcaNotice {
  final String title;
  final String url;
  final DateTime? publishedAt;
  final String? attachmentUrl;

  const BcaNotice({
    required this.title,
    required this.url,
    this.publishedAt,
    this.attachmentUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'publishedAt': publishedAt?.toIso8601String(),
      'attachmentUrl': attachmentUrl,
    };
  }

  factory BcaNotice.fromJson(Map<String, dynamic> json) {
    return BcaNotice(
      title: json['title']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      publishedAt: json['publishedAt'] == null
          ? null
          : DateTime.tryParse(json['publishedAt'].toString()),
      attachmentUrl: json['attachmentUrl']?.toString(),
    );
  }
}
