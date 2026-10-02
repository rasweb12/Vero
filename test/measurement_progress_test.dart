import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vero/features/measurements/data/measurement_repository.dart';
import 'package:vero/features/measurements/domain/measurement_models.dart';
import 'package:vero/features/measurements/presentation/measurement_controller.dart';
import 'package:vero/features/progress/domain/progress_math.dart';
import 'package:vero/features/subscription/domain/app_plan.dart';
import 'package:vero/features/training/domain/training_models.dart';

import 'profile_plan_test.dart' show MemoryDatabase;

void main() {
  late MemoryDatabase database;
  late MeasurementController controller;
  late AppPlan plan;
  setUp(() async {
    database = MemoryDatabase();
    plan = AppPlan.free;
    controller = MeasurementController(
      MeasurementRepository(database, 'a'),
      () => plan,
    );
    await controller.ready;
  });
  tearDown(() => controller.dispose());

  test(
    'free cannot select six metrics or bypass selection in a write',
    () async {
      expect(
        (await controller.selectMetrics(
          BodyMetric.values.take(6).toList(),
        )).isFailure,
        isTrue,
      );
      expect(
        (await controller.saveRecord(
          RegistroMedida(
            id: 'r',
            date: DateTime.now(),
            circumferences: {BodyMetric.arm: 32},
          ),
        )).isFailure,
        isTrue,
      );
      expect(controller.state.requireValue.records, isEmpty);
    },
  );
  test('premium selection persists; downgrade preserves old records', () async {
    plan = AppPlan.annual;
    await controller.selectMetrics(BodyMetric.values.toList());
    await controller.saveRecord(
      RegistroMedida(
        id: 'r',
        date: DateTime.now(),
        weight: 75,
        circumferences: {BodyMetric.arm: 32},
      ),
    );
    plan = AppPlan.free;
    expect(
      controller.state.requireValue
          .allowedMetrics(plan.measurementLimit)
          .length,
      5,
    );
    expect(
      controller.state.requireValue.records.single.values[BodyMetric.arm],
      32,
    );
    final restored = MeasurementController(
      MeasurementRepository(database, 'a'),
      () => plan,
    );
    await restored.ready;
    expect(restored.state.requireValue.records.single.weight, 75);
    restored.dispose();
  });
  test(
    'rejects empty, nonfinite, future and out-of-range measurements',
    () async {
      for (final record in [
        RegistroMedida(id: 'r', date: DateTime.now()),
        RegistroMedida(id: 'r', date: DateTime.now(), weight: double.nan),
        RegistroMedida(id: 'r', date: DateTime.now(), weight: 501),
        RegistroMedida(
          id: 'r',
          date: DateTime.now().add(const Duration(days: 1)),
          weight: 70,
        ),
        RegistroMedida(
          id: 'r',
          date: DateTime.now(),
          circumferences: {BodyMetric.weight: 70},
        ),
      ]) {
        expect((await controller.saveRecord(record)).isFailure, isTrue);
      }
    },
  );
  test(
    'backdated records are chronological, isolated and deletion persists',
    () async {
      final now = DateTime.now();
      await controller.saveRecord(
        RegistroMedida(id: 'new', date: now, weight: 71),
      );
      await controller.saveRecord(
        RegistroMedida(
          id: 'old',
          date: now.subtract(const Duration(days: 1)),
          weight: 72,
        ),
      );
      expect(
        controller.state.requireValue.forMetric(BodyMetric.weight).last.id,
        'new',
      );
      final other = MeasurementController(
        MeasurementRepository(database, 'b'),
        () => plan,
      );
      await other.ready;
      expect(other.state.requireValue.records, isEmpty);
      other.dispose();
      await controller.deleteRecord('new');
      expect(controller.state.requireValue.records.single.id, 'old');
    },
  );
  test('write failure does not show unsaved record', () async {
    database.fail = true;
    expect(
      (await controller.saveRecord(
        RegistroMedida(id: 'r', date: DateTime.now(), weight: 70),
      )).isFailure,
      isTrue,
    );
    expect(controller.state.requireValue.records, isEmpty);
  });
  test('free chart period cannot be bypassed by requesting all history', () {
    final now = DateTime(2026, 5, 31);
    expect(periodStart(AppPlan.free, null, now), DateTime(2026, 2, 28));
    expect(periodStart(AppPlan.free, 12, now), DateTime(2026, 2, 28));
    expect(periodStart(AppPlan.annual, null, now), isNull);
  });
  test(
    'daily means filter dates and moving average uses available records',
    () {
      final data = MeasurementData(
        records: [
          RegistroMedida(id: '1', date: DateTime(2026, 1, 1, 9), weight: 70),
          RegistroMedida(id: '2', date: DateTime(2026, 1, 1, 12), weight: 72),
          RegistroMedida(id: '3', date: DateTime(2026, 1, 2), weight: 73),
        ],
      );
      final points = metricPoints(data, BodyMetric.weight);
      expect(points.length, 2);
      expect(points.first.value, 71);
      expect(movingAverage(points).last.value, 72);
      expect(
        metricPoints(
          data,
          BodyMetric.weight,
          since: DateTime(2026, 1, 2),
        ).single.value,
        73,
      );
    },
  );
  test('projection refuses sparse, flat and away-from-goal trends', () {
    final down = List.generate(
      8,
      (i) => ProgressPoint(DateTime(2026, 1, 1 + i * 3), 80 - i * 0.3),
    );
    expect(projectedDaysToGoal(down, 75), isPositive);
    expect(projectedDaysToGoal(down, 85), isNull);
    expect(projectedDaysToGoal(down.take(3).toList(), 75), isNull);
    expect(
      projectedDaysToGoal(
        down.map((point) => ProgressPoint(point.date, 80)).toList(),
        75,
      ),
      isNull,
    );
  });
  test('weekly constancy counts distinct days, never duplicate sessions', () {
    final routine = Treino(
      id: 'r',
      name: 'A',
      exercises: [
        ExercicioTreino(
          exerciseId: 'squat',
          sets: const [Serie(completed: true)],
        ),
      ],
    );
    final sessions = [
      for (final day in [21, 21, 22])
        TrainingSession(
          id: '$day',
          routine: routine,
          startedAt: DateTime(2026, 9, day),
          finishedAt: DateTime(2026, 9, day, 10),
        ),
    ];
    final points = weeklyConstancy(
      sessions,
      DateTime(2026, 9, 21),
      DateTime(2026, 9, 23),
    );
    expect(points.single.value, closeTo(2 / 7 * 100, 0.001));
  });
}
