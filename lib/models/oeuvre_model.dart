class OeuvreModel {
  final String id;
  final String title;
  final List<String> composers;
  final List<String> arrangers;
  final String year;
  final String genre;
  final String lyrics;       // nom fichier PDF
  final String partition;    // nom fichier PDF
  final String video;        // nom fichier mp4
  final String audio;        // nom fichier mp3
  final bool requiresChoir;
  final bool isVisible;
  final DateTime? createdAt;

  const OeuvreModel({
    required this.id,
    required this.title,
    required this.composers,
    required this.arrangers,
    required this.year,
    required this.genre,
    this.lyrics = '',
    this.partition = '',
    this.video = '',
    this.audio = '',
    required this.requiresChoir,
    this.isVisible = true,
    this.createdAt,
  });

  factory OeuvreModel.fromJson(Map<String, dynamic> json) {
    return OeuvreModel(
      id:           json['_id'] ?? '',
      title:        json['title'] ?? '',
      composers:    List<String>.from(json['composers'] ?? []),
      arrangers:    List<String>.from(json['arrangers'] ?? []),
      year:         json['year'] ?? '',
      genre:        json['genre'] ?? '',
      lyrics:       json['lyrics'] ?? '',
      partition:    json['partition'] ?? '',
      video:        json['video'] ?? '',
      audio:        json['audio'] ?? '',
      requiresChoir: json['requiresChoir'] ?? false,
      isVisible:    json['isVisible'] ?? true,
      createdAt:    json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'title':        title,
    'composers':    composers,
    'arrangers':    arrangers,
    'year':         year,
    'genre':        genre,
    'requiresChoir': requiresChoir,
  };

  OeuvreModel copyWith({
    String? title,
    List<String>? composers,
    List<String>? arrangers,
    String? year,
    String? genre,
    String? lyrics,
    String? partition,
    String? video,
    String? audio,
    bool? requiresChoir,
    bool? isVisible,
  }) {
    return OeuvreModel(
      id:           id,
      title:        title        ?? this.title,
      composers:    composers    ?? this.composers,
      arrangers:    arrangers    ?? this.arrangers,
      year:         year         ?? this.year,
      genre:        genre        ?? this.genre,
      lyrics:       lyrics       ?? this.lyrics,
      partition:    partition    ?? this.partition,
      video:        video        ?? this.video,
      audio:        audio        ?? this.audio,
      requiresChoir: requiresChoir ?? this.requiresChoir,
      isVisible:    isVisible    ?? this.isVisible,
      createdAt:    createdAt,
    );
  }
}