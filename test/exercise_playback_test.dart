import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vero/features/training/data/exercise_media_cache.dart';
import 'package:vero/features/training/domain/exercise_media.dart';
import 'package:vero/features/training/presentation/exercise_playback.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlatform extends VideoPlayerPlatform {
  bool loop = false;
  bool playing = false;
  bool disposed = false;
  double volume = 1;
  double speed = 1;
  Duration position = const Duration(seconds: 2);
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 6),
      size: const Size(200, 200),
    ),
  );
  @override
  Future<void> setLooping(int playerId, bool looping) async {
    loop = looping;
  }

  @override
  Future<void> setVolume(int playerId, double value) async {
    volume = value;
  }

  @override
  Future<void> play(int playerId) async {
    playing = true;
  }

  @override
  Future<void> pause(int playerId) async {
    playing = false;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double value) async {
    speed = value;
  }

  @override
  Future<void> seekTo(int playerId, Duration value) async {
    position = value;
  }

  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Future<void> dispose(int playerId) async {
    disposed = true;
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.teal);
}

void main() {
  for (final fixture in [
    (
      type: ExerciseMediaType.lottie,
      path: 'test/fixtures/playback.json',
      animation: null,
    ),
    (
      type: ExerciseMediaType.animatedWebp,
      path: 'test/fixtures/playback.webp',
      animation: null,
    ),
    (
      type: ExerciseMediaType.rive,
      path: 'test/fixtures/playback.riv',
      animation: 'idle',
    ),
  ]) {
    testWidgets(
      '${fixture.type.name} decodes local bytes, renders, pauses and releases resources',
      (tester) async {
        final playback = await tester.runAsync(
          () => loadExercisePlayback(
            ExerciseMedia(type: fixture.type, animationName: fixture.animation),
            ExerciseMediaSource(file: File(fixture.path)),
            const TestVSync(),
          ),
        );
        expect(playback, isNotNull);
        final player = playback!;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 240,
                height: 240,
                child: player.buildFrame(),
              ),
            ),
          ),
        );
        player.setPlaying(true);
        await tester.pump(const Duration(milliseconds: 200));
        expect(player.playing, isTrue);
        player.setPlaying(false);
        expect(player.playing, isFalse);
        if (player.supportsSpeed) {
          player.restart();
          player.setSpeed(.5);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        player.dispose();
        await tester.pump();
      },
    );
  }

  testWidgets(
    'video uses local source, loops silently, supports restart and speed, and disposes',
    (tester) async {
      final original = VideoPlayerPlatform.instance;
      final platform = FakeVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = original);
      final playback = await tester.runAsync(
        () => loadExercisePlayback(
          const ExerciseMedia(type: ExerciseMediaType.video),
          ExerciseMediaSource(file: File('fixture.mp4')),
          const TestVSync(),
        ),
      );
      final player = playback!;
      expect(platform.loop, isTrue);
      expect(platform.volume, 0);
      player.setPlaying(true);
      await tester.pump();
      expect(platform.playing, isTrue);
      player.setPlaying(false);
      await tester.pump();
      expect(platform.playing, isFalse);
      player.restart();
      player.setSpeed(.5);
      await tester.pump();
      expect(platform.position, Duration.zero);
      player.setPlaying(true);
      await tester.pump();
      expect(platform.speed, .5);
      player.dispose();
      await tester.pump();
      expect(platform.disposed, isTrue);
    },
  );
}
