enum ExerciseMediaType { rive, lottie, animatedWebp, video }

class ExerciseMedia {
  const ExerciseMedia({
    required this.type,
    this.url,
    this.localAsset,
    this.thumbnailUrl,
    this.duration,
    this.loop = true,
    this.version = 1,
    this.animationName,
  });

  final ExerciseMediaType type;
  final String? url;
  final String? localAsset;
  final String? thumbnailUrl;
  final Duration? duration;
  final bool loop;
  final int version;
  // Rive exports must include a named timeline for deterministic playback.
  final String? animationName;

  String get extension => switch (type) {
    ExerciseMediaType.rive => 'riv',
    ExerciseMediaType.lottie => 'json',
    ExerciseMediaType.animatedWebp => 'webp',
    ExerciseMediaType.video => 'mp4',
  };

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'url': url,
    'local_asset': localAsset,
    'thumbnail_url': thumbnailUrl,
    'duration_ms': duration?.inMilliseconds,
    'loop': loop,
    'version': version,
    'animation_name': animationName,
  };

  factory ExerciseMedia.fromJson(Map<String, dynamic> json) {
    final type = ExerciseMediaType.values.byName(json['type'] as String);
    final url = json['url'] as String?;
    final asset = json['local_asset'] as String?;
    final duration = json['duration_ms'] as int?;
    final version = json['version'] as int? ?? 1;
    if ((url == null && asset == null) ||
        version < 1 ||
        (duration != null && (duration <= 0 || duration > 120000))) {
      throw const FormatException('Invalid exercise media.');
    }
    return ExerciseMedia(
      type: type,
      url: url,
      localAsset: asset,
      thumbnailUrl: json['thumbnail_url'] as String?,
      duration: duration == null ? null : Duration(milliseconds: duration),
      loop: json['loop'] as bool? ?? true,
      version: version,
      animationName: json['animation_name'] as String?,
    );
  }
}
