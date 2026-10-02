import 'package:flutter_test/flutter_test.dart';
import 'package:vero/features/progress/domain/progress_assistant.dart';
import 'package:vero/features/reports/data/report_service.dart';
import 'package:vero/features/training/domain/training_models.dart';

TrainingSession _session(DateTime date, double weight) => TrainingSession(
  id: date.toIso8601String(),
  startedAt: date.subtract(const Duration(hours: 1)),
  finishedAt: date,
  routine: Treino(
    id: 'routine',
    name: 'Treino',
    exercises: [
      ExercicioTreino(
        exerciseId: 'squat',
        sets: [Serie(reps: 10, weight: weight, completed: true)],
      ),
    ],
  ),
);

void main() {
  test('consistency score uses distinct trained days and weekly target', () {
    final now = DateTime(2026, 9, 30);
    final history = [
      _session(DateTime(2026, 9, 1), 50),
      _session(DateTime(2026, 9, 8), 50),
      _session(DateTime(2026, 9, 15), 50),
      _session(DateTime(2026, 9, 22), 50),
      _session(DateTime(2026, 9, 22, 18), 50),
    ];
    final result = calculateConsistencyScore(
      history,
      since: DateTime(2026, 9, 1),
      now: now,
      weeklyGoal: 1,
    );
    expect(result.trainedDays, 4);
    expect(result.score, closeTo(10.67, 0.01));
  });

  test('stagnation waits for fourteen days and compares four sessions', () {
    final now = DateTime(2026, 9, 30);
    final history = [
      for (var index = 0; index < 8; index++)
        _session(now.subtract(Duration(days: 35 - index * 3)), 50),
    ];
    final result = detectStagnation(history, now: now);
    expect(result, isNotNull);
    expect(result!.isStagnant, isTrue);
    expect(result.daysWithoutEvolution, greaterThanOrEqualTo(14));
  });

  test('assistant celebrates milestones and stays gentle', () {
    final suggestions = buildProgressSuggestions(
      consistency: const ConsistencyScore(
        score: 72,
        trainedDays: 8,
        periodDays: 30,
        weeklyConsistency: 0.8,
      ),
      stagnation: null,
      completedTrainings: 10,
    );
    expect(celebrationForTrainingCount(10), contains('Dez treinos'));
    expect(suggestions, isNotEmpty);
    expect(suggestions.join(' '), isNot(contains('meta hoje')));
  });

  test('report service creates a PDF document', () async {
    final bytes = await ReportService().buildPdf(
      const ReportSnapshot(
        userName: 'Ana',
        periodLabel: 'Ultimos 30 dias',
        consistencyScore: 72,
        trainingCount: 8,
        totalVolume: 1200,
        weightStart: 80,
        weightEnd: 78.5,
        goalWeight: 75,
        measurementChanges: [],
      ),
    );
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
