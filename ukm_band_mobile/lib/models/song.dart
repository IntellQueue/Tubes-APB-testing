class Song {
  final int id;
  final String title;
  final String artist;
  final String description;
  final String coverPath;
  final String filePath;
  final String? coverUrl;
  final String? audioUrl;
  final String? streamUrl;
  final int plays;
  final int likes;
  final int commentsCount;
  final bool isLiked;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.description,
    required this.coverPath,
    required this.filePath,
    this.coverUrl,
    this.audioUrl,
    this.streamUrl,
    required this.plays,
    required this.likes,
    this.commentsCount = 0,
    this.isLiked = false,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unknown',
      artist: json['artist'] ?? 'Unknown Artist',
      description: json['description'] ?? '',
      coverPath: json['cover_path'] ?? '',
      filePath: json['file_path'] ?? '',
      coverUrl: json['cover_url'],
      audioUrl: json['audio_url'],
      streamUrl: json['stream_url'],
      plays: json['plays'] ?? 0,
      likes: json['likes'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      isLiked: json['is_liked'] ?? false,
    );
  }

  String get displayCover {
    if (coverUrl != null && coverUrl!.isNotEmpty) {
      return coverUrl!;
    }
    return coverPath;
  }

  String get playbackUrl {
    if (filePath.startsWith('assets/')) {
      return filePath;
    }
    if (audioUrl != null && audioUrl!.isNotEmpty) {
      return audioUrl!;
    }
    if (filePath.isNotEmpty) {
      return filePath;
    }
    if (streamUrl != null && streamUrl!.isNotEmpty) {
      return streamUrl!;
    }
    return filePath;
  }

  List<String> get playbackCandidates {
    final candidates = <String>[
      if (filePath.startsWith('assets/')) filePath,
      if (audioUrl != null && audioUrl!.isNotEmpty) audioUrl!,
      if (filePath.isNotEmpty && !filePath.startsWith('assets/')) filePath,
      if (streamUrl != null && streamUrl!.isNotEmpty) streamUrl!,
    ];

    return candidates.toSet().toList();
  }

  bool get isRemoteCover => displayCover.startsWith('http');

  Song copyWith({int? plays, int? likes, int? commentsCount, bool? isLiked}) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      description: description,
      coverPath: coverPath,
      filePath: filePath,
      coverUrl: coverUrl,
      audioUrl: audioUrl,
      streamUrl: streamUrl,
      plays: plays ?? this.plays,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
