enum ContentType {
  video,
  article;

  bool get isArticle => this == ContentType.article;
  bool get isVideo => this == ContentType.video;
}

class VideoInfo {
  final String url;
  final String? title;
  final String? author;
  final String? videoPath;
  final String? audioPath;
  final String? transcription;
  final String? summary;
  final List<String> tags;
  final DateTime? createdAt;
  final ContentType contentType;
  final String? articleContent;

  VideoInfo({
    required this.url,
    this.title,
    this.author,
    this.videoPath,
    this.audioPath,
    this.transcription,
    this.summary,
    this.tags = const [],
    this.createdAt,
    this.contentType = ContentType.video,
    this.articleContent,
  });

  VideoInfo copyWith({
    String? url,
    String? title,
    String? author,
    String? videoPath,
    String? audioPath,
    String? transcription,
    String? summary,
    List<String>? tags,
    DateTime? createdAt,
    ContentType? contentType,
    String? articleContent,
  }) {
    return VideoInfo(
      url: url ?? this.url,
      title: title ?? this.title,
      author: author ?? this.author,
      videoPath: videoPath ?? this.videoPath,
      audioPath: audioPath ?? this.audioPath,
      transcription: transcription ?? this.transcription,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      contentType: contentType ?? this.contentType,
      articleContent: articleContent ?? this.articleContent,
    );
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'author': author,
        'videoPath': videoPath,
        'audioPath': audioPath,
        'transcription': transcription,
        'summary': summary,
        'tags': tags,
        'createdAt': createdAt?.toIso8601String(),
        'contentType': contentType.name,
        'articleContent': articleContent,
      };

  factory VideoInfo.fromJson(Map<String, dynamic> json) => VideoInfo(
        url: json['url'] as String,
        title: json['title'] as String?,
        author: json['author'] as String?,
        videoPath: json['videoPath'] as String?,
        audioPath: json['audioPath'] as String?,
        transcription: json['transcription'] as String?,
        summary: json['summary'] as String?,
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
        contentType: json['contentType'] != null
            ? ContentType.values.firstWhere(
                (e) => e.name == json['contentType'],
                orElse: () => ContentType.video,
              )
            : ContentType.video,
        articleContent: json['articleContent'] as String?,
      );
}

enum PipelineStatus {
  idle,
  // Video pipeline stages
  downloading,
  extractingAudio,
  transcribing,
  // Article pipeline stages
  fetching,
  extracting,
  // Shared stages
  summarizing,
  completed,
  error,
}
