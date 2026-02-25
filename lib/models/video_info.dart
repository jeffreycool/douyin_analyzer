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
      );
}

enum PipelineStatus {
  idle,
  downloading,
  extractingAudio,
  transcribing,
  summarizing,
  completed,
  error,
}
