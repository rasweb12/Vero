import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vero/features/training/data/training_repository.dart';
import 'package:vero/features/training/domain/training_models.dart';
import 'package:vero/features/training/presentation/active_training_page.dart';
import 'package:vero/features/training/presentation/training_controller.dart';

import 'profile_plan_test.dart' show MemoryDatabase;

Treino routine({String id = 'routine-a', int restSeconds = 60}) => Treino(
  id: id,
  name: 'Treino A',
  restSeconds: restSeconds,
  exercises: [
    ExercicioTreino(
      exerciseId: 'bench-press',
      sets: const [Serie(reps: 10, weight: 20), Serie(reps: 8, weight: 22.5)],
    ),
  ],
);

void main() {
  late MemoryDatabase database;
  late TrainingController controller;
  setUp(() async {
    database = MemoryDatabase();
    controller = TrainingController(TrainingRepository(database, 'account-a'));
    await controller.ready;
  });
  tearDown(() => controller.dispose());

  test('routine create/edit/delete retains completed history', () async {
    expect((await controller.saveRoutine(routine())).isSuccess, isTrue);
    await controller.start('routine-a');
    await controller.adjustSet(0, 0, completed: true);
    await controller.finish();
    await controller.deleteRoutine('routine-a');
    expect(controller.state.requireValue.routines, isEmpty);
    expect(controller.state.requireValue.history.single.completedSets, 1);
    expect(controller.state.requireValue.active, isNull);
  });

  test(
    'rapid taps serialize and active workout survives restart offline',
    () async {
      await controller.saveRoutine(routine());
      await controller.start('routine-a');
      await Future.wait(
        List.generate(
          5,
          (_) => controller.adjustSet(0, 0, reps: 1, weight: 2.5),
        ),
      );
      await controller.adjustSet(0, 0, completed: true);
      final restarted = TrainingController(
        TrainingRepository(database, 'account-a'),
      );
      await restarted.ready;
      final active = restarted.state.requireValue.active!;
      expect(active.routine.exercises.first.sets.first.reps, 15);
      expect(active.routine.exercises.first.sets.first.weight, 32.5);
      expect(active.restEndsAt, isNotNull);
      expect(active.completedSets, 1);
      expect((await restarted.start('routine-a')).isFailure, isTrue);
      restarted.dispose();
      final other = TrainingController(
        TrainingRepository(database, 'account-b'),
      );
      await other.ready;
      expect(other.state.requireValue.active, isNull);
      expect(other.state.requireValue.routines, isEmpty);
      other.dispose();
    },
  );

  test(
    'invalid routine and empty workout cannot be saved as completed',
    () async {
      expect(
        (await controller.saveRoutine(
          Treino(id: 'bad', name: '', exercises: []),
        )).isFailure,
        isTrue,
      );
      await controller.saveRoutine(routine());
      await controller.start('routine-a');
      expect((await controller.finish()).isFailure, isTrue);
      await controller.adjustSet(0, 0, reps: -999, weight: -999);
      final set = controller
          .state
          .requireValue
          .active!
          .routine
          .exercises
          .first
          .sets
          .first;
      expect(set.reps, 1);
      expect(set.weight, 0);
      await controller.discard();
      expect(controller.state.requireValue.history, isEmpty);
    },
  );

  test('timer uses deadline rather than elapsed timer ticks', () {
    final start = DateTime(2026, 9, 18, 10);
    final end = start.add(const Duration(seconds: 60));
    expect(remainingRestSeconds(end, start), 60);
    expect(
      remainingRestSeconds(end, start.add(const Duration(seconds: 35))),
      25,
    );
    expect(remainingRestSeconds(end, start.add(const Duration(minutes: 4))), 0);
  });

  test('failed save keeps previous state and a later retry works', () async {
    await controller.saveRoutine(routine());
    await controller.start('routine-a');
    database.fail = true;
    expect((await controller.adjustSet(0, 0, weight: 2.5)).isFailure, isTrue);
    expect(
      controller
          .state
          .requireValue
          .active!
          .routine
          .exercises
          .first
          .sets
          .first
          .weight,
      20,
    );
    database.fail = false;
    expect((await controller.adjustSet(0, 0, weight: 2.5)).isSuccess, isTrue);
    expect(
      controller
          .state
          .requireValue
          .active!
          .routine
          .exercises
          .first
          .sets
          .first
          .weight,
      22.5,
    );
  });

  test(
    'previous record uses same exercise and set, ignoring unfinished sets',
    () {
      final now = DateTime.now();
      final finished = TrainingSession(
        id: 'past',
        routine: Treino(
          id: 'r',
          name: 'Anterior',
          exercises: [
            ExercicioTreino(
              exerciseId: 'bench-press',
              sets: const [
                Serie(weight: 25, completed: true),
                Serie(weight: 30),
              ],
            ),
          ],
        ),
        startedAt: now.subtract(const Duration(days: 7, hours: 1)),
        finishedAt: now.subtract(const Duration(days: 7)),
      );
      final data = TrainingData(
        history: [finished],
        active: TrainingSession(
          id: 'current',
          routine: routine(),
          startedAt: now,
        ),
      );
      expect(previousSet(data, 'bench-press', 0)?.set.weight, 25);
      expect(previousSet(data, 'bench-press', 1), isNull);
      expect(previousSet(data, 'squat', 0), isNull);
    },
  );

  test('constancy counts distinct local days, not sessions', () {
    final now = DateTime(2026, 9, 18, 18);
    final completed = Treino(
      id: 'r',
      name: 'A',
      exercises: [
        ExercicioTreino(
          exerciseId: 'squat',
          sets: const [Serie(completed: true)],
        ),
      ],
    );
    final data = TrainingData(
      history: [
        for (final day in [17, 17, 18])
          TrainingSession(
            id: '$day',
            routine: completed,
            startedAt: DateTime(2026, 9, day, 9),
            finishedAt: DateTime(2026, 9, day, 10),
          ),
      ],
    );
    expect(data.trainedDaysThisWeek(now), 2);
  });
}
