import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vero/app.dart';
import 'package:vero/features/auth/presentation/auth_controller.dart';
import 'package:vero/features/profile/domain/usuario.dart';
import 'package:vero/features/profile/presentation/profile_providers.dart';
import 'package:vero/features/training/data/training_repository.dart';
import 'package:vero/features/training/domain/exercise_library.dart';
import 'package:vero/features/training/domain/training_models.dart';
import 'package:vero/features/training/presentation/training_controller.dart';
import 'package:vero/shared/providers/local_database_provider.dart';
import 'package:vero/shared/providers/shared_preferences_provider.dart';
import 'package:vero/shared/utils/result.dart';

import 'profile_plan_test.dart' show MemoryDatabase;
import 'support/fake_auth_repository.dart';

const customExercise = Exercicio(
  id: 'custom-articulado', name: 'Crucifixo articulado',
  muscleGroup: 'Peito', type: 'Maquina',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryDatabase database;
  late TrainingController controller;

  setUpAll(() async {
    final textFont = FontLoader('Inter')..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await textFont.load();
    final iconFont = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await iconFont.load();
  });

  setUp(() async {
    database = MemoryDatabase();
    controller = TrainingController(TrainingRepository(database, 'account-a'));
    await controller.ready;
  });
  tearDown(() => controller.dispose());

  test('catalog has unique stable ids and finds aliases without accents', () {
    expect(exerciseLibrary.length, greaterThanOrEqualTo(60));
    expect(exerciseLibrary.map((exercise) => exercise.id).toSet().length, exerciseLibrary.length);
    expect(exerciseById('bench-press').name, 'Supino reto');
    final peckDeck = exerciseById('pec-deck');
    for (final query in ['Peck deck', 'Pec deck', 'voador', 'crucifixo na m\u00e1quina']) {
      expect(exerciseMatchesQuery(peckDeck, query), isTrue, reason: query);
    }
    expect(exerciseMatchesQuery(exerciseById('lateral-raise'), 'eleva\u00e7\u00e3o lateral'), isTrue);
    expect(exerciseMatchesQuery(peckDeck, 'halteres'), isFalse);
    expect(exerciseById('missing-id').name, 'Exercicio indisponivel');
  });

  test('legacy data loads without custom exercises and unknown versions stay preserved', () async {
    final legacy = TrainingData().toJson()..['version'] = 1;
    legacy.remove('custom_exercises');
    database.values['training:account-a'] = jsonEncode(legacy);
    await controller.reload();
    expect(controller.state.requireValue.customExercises, isEmpty);
    final unknown = jsonEncode({...legacy, 'version': 99});
    database.values['training:account-a'] = unknown;
    expect((await controller.repository.load()).isFailure, isTrue);
    expect(database.values['training:account-a'], unknown);
  });

  test('custom exercise survives restart, workout, history and routine deletion offline', () async {
    expect((await controller.saveCustomExercise(customExercise)).isSuccess, isTrue);
    final routine = Treino(id: 'routine-custom', name: 'Peito', exercises: [
      ExercicioTreino(exerciseId: customExercise.id, sets: const [Serie(weight: 30)]),
    ]);
    expect((await controller.saveRoutine(routine)).isSuccess, isTrue);
    await controller.start(routine.id);
    await controller.adjustSet(0, 0, completed: true);
    await controller.clearRest();
    await controller.finish();
    await controller.deleteRoutine(routine.id);
    final restarted = TrainingController(TrainingRepository(database, 'account-a'));
    addTearDown(restarted.dispose);
    await restarted.ready;
    final data = restarted.state.requireValue;
    expect(data.customExercises.single.name, customExercise.name);
    expect(data.history.single.completedSets, 1);
    expect(data.active, isNull);
    expect(exerciseById(data.history.single.routine.exercises.single.exerciseId,
      customExercises: data.customExercises).name, customExercise.name);
    final otherAccount = await TrainingRepository(database, 'account-b').load();
    expect((otherAccount as Success<TrainingData>).value.customExercises, isEmpty);
    expect(jsonDecode(database.values['training:account-a']!)['version'], 2);
  });

  test('creating an exercise during a workout and discarding keeps the catalog', () async {
    await controller.saveRoutine(Treino(id: 'a', name: 'A', exercises: [
      ExercicioTreino(exerciseId: 'bench-press', sets: const [Serie()]),
    ]));
    await controller.start('a');
    await controller.saveCustomExercise(customExercise);
    expect(controller.state.requireValue.active?.routine.id, 'a');
    await controller.discard();
    expect(controller.state.requireValue.customExercises.single.id, customExercise.id);
  });

  test('duplicates, aliases and concurrent duplicate submissions are rejected', () async {
    final results = await Future.wait([
      controller.saveCustomExercise(customExercise),
      controller.saveCustomExercise(const Exercicio(id: 'custom-another',
        name: '  CRUCIFIXO  ARTICULADO  ', muscleGroup: 'Peito', type: 'Maquina')),
    ]);
    expect(results.where((result) => result.isSuccess).length, 1);
    expect(controller.state.requireValue.customExercises.length, 1);
    expect((await controller.saveCustomExercise(const Exercicio(id: 'custom-voador',
      name: 'Voador', muscleGroup: 'Peito', type: 'Maquina'))).isFailure, isTrue);
    expect((await controller.saveCustomExercise(customExercise)).isFailure, isTrue);
  });

  test('invalid fields and failed storage do not commit a new exercise', () async {
    for (final exercise in [
      const Exercicio(id: 'custom-empty', name: ' ', muscleGroup: 'Peito', type: 'Maquina'),
      const Exercicio(id: 'bench-press', name: 'A', muscleGroup: 'Peito', type: 'Maquina'),
      const Exercicio(id: 'custom-group', name: 'A', muscleGroup: '', type: 'Maquina'),
      const Exercicio(id: 'custom-equipment', name: 'A', muscleGroup: 'Peito', type: ''),
    ]) {
      expect((await controller.saveCustomExercise(exercise)).isFailure, isTrue);
    }
    database.fail = true;
    expect((await controller.saveCustomExercise(customExercise)).isFailure, isTrue);
    expect(controller.state.requireValue.customExercises, isEmpty);
    database.fail = false;
    expect((await controller.saveCustomExercise(customExercise)).isSuccess, isTrue);
  });

  Future<ProviderContainer> mount(WidgetTester tester, {double width = 320}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final auth = FakeAuthRepository()..currentAccount = FakeAuthRepository.account;
    addTearDown(auth.changes.close);
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
      authRepositoryProvider.overrideWithValue(auth),
      localDatabaseProvider.overrideWithValue(database),
      profileProvider.overrideWith((ref) async => const Success(
        Usuario(id: 'user-a', email: 'ana@example.com', name: 'Ana'),
      )),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: const RepaintBoundary(key: ValueKey('exercise-preview'), child: VeroApp())));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> choose(WidgetTester tester, String key, String value) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('VERO_CAPTURE_PREVIEWS')) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('exercise-preview')));
      final image = await boundary.toImage();
      try {
        final bytes = await image.toByteData(format: ImageByteFormat.png);
        Directory('build/ui-previews').createSync(recursive: true);
        File('build/ui-previews/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      } finally { image.dispose(); }
    });
  }

  testWidgets('create exercise from the routine picker and display it in active and history views', (tester) async {
    final container = await mount(tester);
    await tester.tap(find.text('Criar rotina'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome do treino'), 'Treino personalizado');
    await tester.tap(find.text('Adicionar exercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Criar exercicio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome do exercicio'), customExercise.name);
    await choose(tester, 'custom-muscle-group', 'Peito');
    await choose(tester, 'custom-equipment', 'Maquina');
    await capture(tester, 'custom-exercise-phone');
    await tester.ensureVisible(find.text('Salvar exercicio'));
    await tester.tap(find.text('Salvar exercicio'));
    await tester.pumpAndSettle();
    expect(find.text(customExercise.name), findsOneWidget);
    await tester.tap(find.byTooltip('Salvar treino'));
    await tester.pumpAndSettle();
    expect(container.read(trainingControllerProvider).requireValue.customExercises.single.name, customExercise.name);
    await tester.tap(find.text('Iniciar treino'));
    await tester.pumpAndSettle();
    expect(find.text(customExercise.name), findsOneWidget);
    await tester.tap(find.text('Concluir serie').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Finalizar treino'), 300,
      scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('Finalizar treino'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(find.text(customExercise.name), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library search aliases, creation validation and retry on a wide layout', (tester) async {
    await mount(tester, width: 900);
    await tester.tap(find.text('Treinos'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Biblioteca de exercicios'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Buscar exercicio'), 'voador');
    await tester.pumpAndSettle();
    expect(find.text('Peck deck'), findsOneWidget);
    await capture(tester, 'exercise-library-wide');
    await tester.enterText(find.widgetWithText(TextField, 'Buscar exercicio'), 'Exercicio novo');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Criar exercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar exercicio'));
    await tester.pumpAndSettle();
    expect(find.text('Selecione o grupo muscular.'), findsOneWidget);
    expect(find.text('Selecione o equipamento.'), findsOneWidget);
    await choose(tester, 'custom-muscle-group', 'Peito');
    await choose(tester, 'custom-equipment', 'Maquina');
    database.fail = true;
    await tester.tap(find.text('Salvar exercicio'));
    await tester.pumpAndSettle();
    expect(find.text('Storage failure'), findsOneWidget);
    database.fail = false;
    await tester.tap(find.text('Salvar exercicio'));
    await tester.pumpAndSettle();
    expect(find.text('Exercicio novo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
