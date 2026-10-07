import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:rive/rive.dart' as rive;
import 'package:video_player/video_player.dart';

import '../data/exercise_media_cache.dart';
import '../domain/exercise_media.dart';

abstract class ExercisePlayback extends ChangeNotifier {
  bool get playing;
  bool get supportsSpeed => false;
  bool failed = false;
  Widget buildFrame();
  void setPlaying(bool value);
  void restart();
  void setSpeed(double value) {}
}

typedef ExercisePlaybackLoader =
    Future<ExercisePlayback> Function(
      ExerciseMedia media,
      ExerciseMediaSource source,
      TickerProvider ticker,
    );

Future<ExercisePlayback> loadExercisePlayback(
  ExerciseMedia media,
  ExerciseMediaSource source,
  TickerProvider ticker,
) async {
  if (media.type == ExerciseMediaType.video) {
    final controller = source.asset != null
        ? VideoPlayerController.asset(source.asset!)
        : VideoPlayerController.file(source.file!);
    try {
      await controller.initialize().timeout(const Duration(seconds: 20));
      if (controller.value.duration <= Duration.zero || controller.value.duration > const Duration(minutes: 2)) {
        throw const FormatException('Expected a short exercise video.');
      }
      await controller.setLooping(media.loop);
      await controller.setVolume(0);
      return _VideoPlayback(controller);
    } on Object {
      await controller.dispose();
      rethrow;
    }
  }
  final bytes = source.asset == null
      ? await source.file!.readAsBytes()
      : (await rootBundle.load(source.asset!)).buffer.asUint8List();
  switch (media.type) {
    case ExerciseMediaType.lottie:
      final composition = LottieComposition.parseJsonBytes(bytes);
      // External raster/font dependencies would break the single-file offline contract.
      if (composition.images.isNotEmpty ||
          composition.fonts.isNotEmpty ||
          composition.duration <= Duration.zero || composition.duration > const Duration(minutes: 2)) {
        throw const FormatException(
          'Use a self-contained shape-only Lottie export.',
        );
      }
      return _LottiePlayback(composition, ticker, media.loop);
    case ExerciseMediaType.rive:
      final file = await rive.File.decode(
        bytes,
        riveFactory: rive.Factory.flutter,
      );
      if (file == null) throw const FormatException('Invalid Rive file.');
      rive.Artboard? artboard;
      rive.Animation? animation;
      try {
        artboard = file.defaultArtboard();
        animation = artboard?.animationNamed(
          media.animationName ?? 'execution',
        );
        if (artboard == null || animation == null || !animation.duration.isFinite || animation.duration <= 0 || animation.duration > 120) {
          throw const FormatException('Missing execution timeline.');
        }
        return _RivePlayback(file, artboard, animation, media.loop);
      } on Object {
        animation?.dispose();
        artboard?.dispose();
        file.dispose();
        rethrow;
      }
    case ExerciseMediaType.animatedWebp:
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final codec = await ui.instantiateImageCodecWithSize(buffer, getTargetSize: (width, height) {
        final longest = width > height ? width : height;
        final scale = longest > 960 ? 960 / longest : 1.0;
        return ui.TargetImageSize(width: (width * scale).round().clamp(1, 960), height: (height * scale).round().clamp(1, 960));
      });
      try {
        if (codec.frameCount > 3600) throw const FormatException('Animation too long.');
        final first = await codec.getNextFrame();
        return _WebpPlayback(codec, first, media.loop);
      } on Object {
        codec.dispose();
        rethrow;
      }
    case ExerciseMediaType.video:
      throw StateError('Video is initialized separately.');
  }
}

class _LottiePlayback extends ExercisePlayback {
  _LottiePlayback(this.composition, TickerProvider ticker, this.loop)
    : controller = AnimationController(
        vsync: ticker,
        duration: composition.duration,
      );
  final LottieComposition composition;
  final AnimationController controller;
  final bool loop;
  @override
  bool get playing => controller.isAnimating;
  @override
  bool get supportsSpeed => true;
  @override
  Widget buildFrame() => Lottie(
    composition: composition,
    controller: controller,
    fit: BoxFit.contain,
  );
  @override
  void setPlaying(bool value) {
    if (!value) {
      controller.stop();
      return;
    }
    if (playing) return;
    if (loop) {
      controller.repeat();
    } else {
      controller.forward();
    }
  }

  @override
  void restart() {
    final resume = playing;
    controller.value = 0;
    if (resume) setPlaying(true);
  }

  @override
  void setSpeed(double value) {
    final resume = playing;
    controller.stop();
    controller.duration = Duration(
      microseconds: (composition.duration.inMicroseconds / value).round(),
    );
    if (resume) setPlaying(true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _VideoPlayback extends ExercisePlayback {
  _VideoPlayback(this.controller) {
    controller.addListener(_changed);
  }
  final VideoPlayerController controller;
  bool _disposed = false;
  void _changed() {
    if (controller.value.hasError && !failed) {
      failed = true;
      notifyListeners();
    }
  }

  void _run(Future<void> operation) {
    unawaited(
      operation.catchError((Object error) {
        if (_disposed || failed) return;
        failed = true;
        notifyListeners();
      }),
    );
  }

  @override
  bool get playing => controller.value.isPlaying;
  @override
  bool get supportsSpeed => true;
  @override
  Widget buildFrame() => Center(
    child: AspectRatio(
      aspectRatio: controller.value.aspectRatio,
      child: VideoPlayer(controller),
    ),
  );
  @override
  void setPlaying(bool value) =>
      _run(value ? controller.play() : controller.pause());
  @override
  void restart() => _run(controller.seekTo(Duration.zero));
  @override
  void setSpeed(double value) => _run(controller.setPlaybackSpeed(value));
  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(_changed);
    unawaited(controller.dispose());
    super.dispose();
  }
}

class _RivePlayback extends ExercisePlayback {
  _RivePlayback(this.file, this.artboard, rive.Animation animation, bool loop)
    : painter = _ExercisePainter(animation, loop);
  final rive.File file;
  final rive.Artboard artboard;
  final _ExercisePainter painter;
  @override
  bool get playing => painter.playing;
  @override
  bool get supportsSpeed => true;
  @override
  Widget buildFrame() =>
      rive.RiveArtboardWidget(artboard: artboard, painter: painter);
  @override
  void setPlaying(bool value) {
    painter.playing = value;
    painter.scheduleRepaint();
  }

  @override
  void restart() {
    painter.elapsed = 0;
    painter.animation.time = 0;
    painter.animation.apply();
    painter.scheduleRepaint();
  }

  @override
  void setSpeed(double value) => painter.speed = value;
  @override
  void dispose() {
    painter.dispose();
    painter.animation.dispose();
    artboard.dispose();
    file.dispose();
    super.dispose();
  }
}

final class _ExercisePainter extends rive.BasicArtboardPainter {
  _ExercisePainter(this.animation, this.loop) : super(fit: rive.Fit.contain);
  final rive.Animation animation;
  final bool loop;
  bool playing = false;
  double elapsed = 0;
  double speed = 1;
  @override
  bool advance(double elapsedSeconds) {
    if (playing) elapsed += elapsedSeconds * speed;
    animation.time = loop
        ? elapsed % animation.duration
        : elapsed.clamp(0, animation.duration);
    animation.apply();
    artboard?.advance(0);
    if (!loop && elapsed >= animation.duration) playing = false;
    return playing;
  }
}

class _WebpPlayback extends ExercisePlayback {
  _WebpPlayback(this.codec, ui.FrameInfo first, this.loop)
    : _image = first.image,
      _duration = first.duration;
  final ui.Codec codec;
  final bool loop;
  ui.Image _image;
  Duration _duration;
  Timer? _timer;
  bool _playing = false;
  bool _disposed = false;
  bool _decoding = false;
  int _frame = 0;
  @override
  bool get playing => _playing;
  @override
  Widget buildFrame() => RawImage(image: _image, fit: BoxFit.contain);
  @override
  void setPlaying(bool value) {
    _playing = value;
    _timer?.cancel();
    if (value && !_decoding) _schedule();
  }

  void _schedule() {
    if (!_playing || _disposed || codec.frameCount <= 1) return;
    _timer = Timer(
      _duration > Duration.zero ? _duration : const Duration(milliseconds: 100),
      _next,
    );
  }

  Future<void> _next() async {
    if (_disposed || !_playing) return;
    if (!loop && _frame == codec.frameCount - 1) {
      _playing = false;
      notifyListeners();
      return;
    }
    _decoding = true;
    try {
      final next = await codec.getNextFrame();
      if (_disposed) {
        next.image.dispose();
        return;
      }
      _image.dispose();
      _image = next.image;
      _duration = next.duration;
      _frame = (_frame + 1) % codec.frameCount;
      notifyListeners();
    } on Object {
      if (!_disposed) {
        failed = true;
        _playing = false;
        notifyListeners();
      }
    } finally {
      _decoding = false;
      if (_disposed) {
        codec.dispose();
      } else {
        _schedule();
      }
    }
  }

  @override
  void restart() {
    // Reopening via the parent is required to rewind a streaming image codec.
  }
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _image.dispose();
    if (!_decoding) codec.dispose();
    super.dispose();
  }
}
