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
