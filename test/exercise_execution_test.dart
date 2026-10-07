import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vero/features/training/data/exercise_media_cache.dart';
import 'package:vero/features/training/data/exercise_repository.dart';
import 'package:vero/features/training/domain/exercise_library.dart';
import 'package:vero/features/training/domain/exercise_media.dart';
import 'package:vero/features/training/domain/training_models.dart';
import 'package:vero/features/training/presentation/exercise_animation_player.dart';
import 'package:vero/features/training/presentation/exercise_detail_page.dart';
import 'package:vero/features/training/presentation/exercise_playback.dart';
import 'package:vero/features/training/presentation/exercise_providers.dart';
import 'package:vero/shared/providers/local_database_provider.dart';
import 'package:vero/shared/theme/app_theme.dart';
import 'package:vero/shared/utils/result.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'profile_plan_test.dart' show MemoryDatabase;

const demoMedia = ExerciseMedia(
  type: ExerciseMediaType.lottie,
  localAsset: 'assets/exercises/demo.json',
);

class FakePlayback extends ExercisePlayback {
  bool _playing = false;
  bool disposed = false;
  int restarts = 0;
  double speed = 1;
  @override
  bool get playing => _playing;
  @override
  bool get supportsSpeed => true;
  @override
  Widget buildFrame() => const ColoredBox(color: Colors.teal);
  @override
  void setPlaying(bool value) => _playing = value;
  @override
  void restart() => restarts++;
  @override
  void setSpeed(double value) => speed = value;
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Map<String, dynamic>> bundled;
  late MemoryDatabase database;
  setUpAll(() async {
    final json =
        jsonDecode(await rootBundle.loadString('assets/exercises/catalog.json'))
            as Map<String, dynamic>;
    bundled = (json['exercises'] as List).cast<Map<String, dynamic>>();
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  setUp(() {
    database = MemoryDatabase();
  });

  test(
    'five enriched exercises roundtrip without changing routine references',
    () {
      expect(bundled, hasLength(5));
      for (final json in bundled) {
        final exercise = Exercicio.fromJson(json);
        expect(
          Exercicio.fromJson(exercise.toJson()).toJson(),
          exercise.toJson(),
        );
        expect(exercise.instructions, isNotEmpty);
        expect(exercise.commonErrors, isNotEmpty);
        expect(exercise.safetyTips, isNotEmpty);
        expect(exercise.equipmentNames, isNotEmpty);
        expect(exercise.media, isNull);
        expect(exerciseLibrary.any((item) => item.id == exercise.id), isTrue);
        expect(
          exercise.alternatives.every(
            (id) => exerciseLibrary.any((item) => item.id == id),
          ),
          isTrue,
        );
        expect(
          () => exercise.instructions.add('change'),
          throwsUnsupportedError,
        );
      }
      final prescription = ExercicioTreino(
        exerciseId: 'incline-dumbbell',
        sets: const [Serie(reps: 8, weight: 12.5)],
        intensityTechnique: 'Pausa no topo',
        notes: 'Controlar a descida',
      );
      expect(
        prescription.withSets(const [Serie(reps: 6)]).intensityTechnique,
        prescription.intensityTechnique,
      );
      expect(
        ExercicioTreino.fromJson(prescription.toJson()).notes,
        prescription.notes,
      );
      expect(prescription.toJson().containsKey('name'), isFalse);
    },
  );

  test('all four media types roundtrip and malformed metadata is rejected', () {
    for (final type in ExerciseMediaType.values) {
      final media = ExerciseMedia(
        type: type,
        url: 'https://example.com/media',
        duration: const Duration(seconds: 5),
        version: 2,
        animationName: 'execution',
      );
      expect(ExerciseMedia.fromJson(media.toJson()).toJson(), media.toJson());
    }
    expect(
      () => ExerciseMedia.fromJson({'type': 'video'}),
      throwsFormatException,
    );
    expect(
      () => ExerciseMedia.fromJson({
        'type': 'video',
        'url': 'https://example.com',
        'version': 0,
      }),
      throwsFormatException,
    );
  });

  test(
    'repository reads offline, refresh persists metadata and failure preserves cache',
    () async {
      var requests = 0;
      var fail = false;
      final remote = {
        ...bundled.first,
        'name': 'Supino atualizado',
        'media': demoMedia.toJson(),
      };
      final repository = ExerciseRepository(
        database,
        loadBundled: () async => bundled,
        loadRemote: () async {
          requests++;
          if (fail) throw const SocketException('offline');
          return [remote];
        },
      );
      final first = await repository.load();
      expect(first.isSuccess, isTrue);
      expect(requests, 0);
      expect((await repository.refresh()).isSuccess, isTrue);
      final stored = database.values[ExerciseRepository.cacheKey];
      final restarted = ExerciseRepository(
        database,
        loadBundled: () async => bundled,
      );
      final offline =
          (await restarted.load() as Success<List<Exercicio>>).value;
      expect(
        exerciseById('incline-dumbbell', catalog: offline).name,
        'Supino atualizado',
      );
      expect(
        exerciseById('incline-dumbbell', catalog: offline).media?.type,
        ExerciseMediaType.lottie,
      );
      fail = true;
      expect((await repository.refresh()).isFailure, isTrue);
      expect(database.values[ExerciseRepository.cacheKey], stored);
      database.values[ExerciseRepository.cacheKey] = 'damaged';
      expect((await repository.load()).isSuccess, isTrue);
      expect(database.values[ExerciseRepository.cacheKey], 'damaged');
    },
  );

  test(
    'invalid or duplicate remote catalog never replaces the last good snapshot',
    () async {
      database.values[ExerciseRepository.cacheKey] = 'preserve';
      final repository = ExerciseRepository(
        database,
        loadBundled: () async => bundled,
        loadRemote: () async => [bundled.first, bundled.first],
      );
      expect((await repository.refresh()).isFailure, isTrue);
      expect(database.values[ExerciseRepository.cacheKey], 'preserve');
    },
  );

  test('search ignores accents/case and filters combine without mutation', () {
    final exercises = bundled.map(Exercicio.fromJson).toList();
    expect(
      filterExercises(
        exercises,
        query: 'SUPINO inclinado',
        muscleGroup: 'Peito',
        equipment: 'Banco inclinado',
        difficulty: ExerciseDifficulty.intermediate,
      ).single.id,
      'incline-dumbbell',
    );
    expect(
      filterExercises(
        exercises,
        query: 'b\u00edceps',
        muscleGroup: 'Biceps',
      ).single.id,
      'biceps-curl',
    );
    expect(
      filterExercises(
        exercises,
        equipment: 'Halteres',
        difficulty: ExerciseDifficulty.advanced,
      ),
      isEmpty,
    );
    expect(
      filterExercises(
        exercises,
        excluded: {'squat'},
      ).any((exercise) => exercise.id == 'squat'),
      isFalse,
    );
    expect(exercises, hasLength(5));
  });

  group('on-demand media cache', () {
    late Directory root;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('vero-media-test-');
    });
    tearDown(() async {
      await root.delete(recursive: true);
    });
    test(
      'cached file works offline, version changes key, LRU respects disk budget',
      () async {
        var requests = 0;
        var connected = true;
        final cache = ExerciseMediaCache(
          directory: () async => root.path,
          maxFileBytes: 16,
          maxCacheBytes: 24,
          download: (uri, file, limit) async {
            requests++;
            if (!connected) throw const SocketException('offline');
            await file.writeAsBytes(List.filled(12, 1));
          },
        );
        const media = ExerciseMedia(
          type: ExerciseMediaType.video,
          url: 'https://example.com/demo.mp4',
        );
        final first =
            await cache.resolve(media) as Success<ExerciseMediaSource>;
        connected = false;
        final cached =
            await cache.resolve(media) as Success<ExerciseMediaSource>;
        expect(cached.value.file?.path, first.value.file?.path);
        expect(requests, 1);
        connected = true;
        final second =
            await cache.resolve(
                  const ExerciseMedia(
                    type: ExerciseMediaType.video,
                    url: 'https://example.com/demo.mp4',
                    version: 2,
                  ),
                )
                as Success<ExerciseMediaSource>;
        expect(second.value.file?.path, isNot(first.value.file?.path));
        await first.value.file!.setLastModified(DateTime(2000));
        await second.value.file!.setLastModified(DateTime(2001));
        await cache.resolve(
          const ExerciseMedia(
            type: ExerciseMediaType.video,
            url: 'https://example.com/other.mp4',
          ),
        );
        final files = await root
            .list()
            .where((entry) => entry is File)
            .cast<File>()
            .toList();
        expect(files, hasLength(2));
        expect(await first.value.file!.exists(), isFalse);
      },
    );
    test(
      'concurrent cache hits deduplicate and failed/oversized downloads leave no partial files',
      () async {
        var requests = 0;
        var size = 12;
        final cache = ExerciseMediaCache(
          directory: () async => root.path,
          maxFileBytes: 16,
          maxCacheBytes: 24,
          download: (uri, file, limit) async {
            requests++;
            await file.writeAsBytes(List.filled(size, 1));
          },
        );
        const media = ExerciseMedia(
          type: ExerciseMediaType.lottie,
          url: 'https://example.com/a.json',
        );
        final results = await Future.wait([
          cache.resolve(media),
          cache.resolve(media),
        ]);
        expect(results.every((result) => result.isSuccess), isTrue);
        expect(requests, 1);
        size = 17;
        expect(
          (await cache.resolve(
            const ExerciseMedia(
              type: ExerciseMediaType.lottie,
              url: 'https://example.com/b.json',
            ),
          )).isFailure,
          isTrue,
        );
        expect(await root.list().length, 1);
        final failing = ExerciseMediaCache(
          directory: () async => root.path,
          download: (uri, file, limit) async {
            await file.writeAsBytes([1]);
            throw const SocketException('disconnected');
          },
        );
        expect(
          (await failing.resolve(
            const ExerciseMedia(
              type: ExerciseMediaType.video,
              url: 'https://example.com/failed.mp4',
            ),
          )).isFailure,
          isTrue,
        );
        expect(await root.list().length, 1);
        expect(
          (await cache.resolve(
            const ExerciseMedia(
              type: ExerciseMediaType.video,
              url: 'http://example.com',
            ),
          )).isFailure,
          isTrue,
        );
        expect(
          (await cache.resolve(
            const ExerciseMedia(
              type: ExerciseMediaType.lottie,
              localAsset: 'assets/exercises/../private.json',
            ),
          )).isFailure,
          isTrue,
        );
      },
    );
  });

  Future<void> mountPlayer(
    WidgetTester tester, {
    ExerciseMedia? media = demoMedia,
    required ExercisePlaybackLoader loader,
    bool reducedMotion = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          navigatorObservers: [exerciseRouteObserver],
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: Scaffold(
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    children: [
                      ExerciseAnimationPlayer(
                        media: media,
                        description: 'Desca com controle e retorne.',
                        loader: loader,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('no media renders placeholder without invoking loader', (
    tester,
  ) async {
    await mountPlayer(
      tester,
      media: null,
      loader: (_, source, ticker) async => throw StateError('must not load'),
    );
    expect(find.text('Animacao em preparacao'), findsOneWidget);
    expect(find.byTooltip('Pausar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading, pause, restart, speed, background and disposal', (
    tester,
  ) async {
    final completer = Completer<ExercisePlayback>();
    final playback = FakePlayback();
    await mountPlayer(tester, loader: (_, source, ticker) => completer.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(playback);
    await tester.pump();
    await tester.pump();
    expect(playback.playing, isTrue);
    await tester.tap(find.byTooltip('Pausar'));
    await tester.pump();
    expect(playback.playing, isFalse);
    await tester.tap(find.byTooltip('Reiniciar'));
    await tester.pump();
    expect(playback.restarts, 1);
    await tester.tap(find.text('0.5x'));
    await tester.pump();
    expect(playback.speed, .5);
    await tester.tap(find.byTooltip('Reproduzir'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(playback.playing, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(playback.playing, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(playback.disposed, isTrue);
  });

  testWidgets('decoder failure can retry without exposing technical errors', (
    tester,
  ) async {
    var attempts = 0;
    await mountPlayer(
      tester,
      loader: (_, source, ticker) async {
        attempts++;
        if (attempts == 1) throw const FormatException('technical error');
        return FakePlayback();
      },
    );
    expect(find.text('Animacao indisponivel'), findsOneWidget);
    expect(find.textContaining('technical'), findsNothing);
    await tester.tap(find.byTooltip('Tentar novamente'));
    await tester.pump();
    await tester.pump();
    expect(find.byTooltip('Pausar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'late load after unmount disposes its controller and reduced motion does not autoplay',
    (tester) async {
      final pending = Completer<ExercisePlayback>();
      final latePlayback = FakePlayback();
      await mountPlayer(tester, loader: (_, source, ticker) => pending.future);
      await tester.pumpWidget(const SizedBox());
      pending.complete(latePlayback);
      await tester.pump();
      expect(latePlayback.disposed, isTrue);
      final paused = FakePlayback();
      await mountPlayer(
        tester,
        reducedMotion: true,
        loader: (_, source, ticker) async => paused,
      );
      expect(paused.playing, isFalse);
      expect(find.byTooltip('Reproduzir'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'detail displays prescribed sets, safety, alternatives and readable large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = [
        ...exerciseLibrary.where(
          (exercise) => exercise.id != 'incline-dumbbell',
        ),
        ...bundled.map(Exercicio.fromJson),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(database),
            exerciseCatalogProvider.overrideWith((ref) async => catalog),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: ExerciseDetailPage(
                id: 'incline-dumbbell',
                workout: ExerciseDetailContext(
                  exercise: ExercicioTreino(
                    exerciseId: 'incline-dumbbell',
                    sets: const [
                      Serie(reps: 8, weight: 12.5),
                      Serie(reps: 6, weight: 15),
                    ],
                    intensityTechnique: 'Pausa controlada',
                    notes: 'Sem impulso',
                  ),
                  restSeconds: 90,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Animacao em preparacao'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Serie 1: 8 repeticoes · 12,5 kg'),
        200,
      );
      expect(find.text('Serie 2: 6 repeticoes · 15 kg'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Pausa controlada'), 200);
      await tester.scrollUntilVisible(find.text('Alternativas'), 300);
      await tester.scrollUntilVisible(
        find.text('Supino inclinado com barra'),
        200,
      );
      expect(find.text('Supino inclinado com barra'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
