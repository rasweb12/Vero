import 'package:flutter_test/flutter_test.dart';
import 'package:vero/features/training/domain/training_models.dart';
import 'package:vero/shared/config/app_config.dart';

TrainingSession _session(int index) {
  final date = DateTime(2026, 1, 1).add(Duration(days: index));
  return TrainingSession(
    id: 'session-$index',
    routine: Treino(
      id: 'routine-$index',
      name: 'Treino $index',
      exercises: [
        ExercicioTreino(
          exerciseId: 'supino-reto',
          sets: const [Serie(reps: 10, weight: 20, completed: true)],
        ),
      ],
    ),
    startedAt: date,
    finishedAt: date.add(const Duration(minutes: 30)),
  );
}

void main() {
  test('training history returns newest pages without changing the source', () {
    final history = List<TrainingSession>.generate(45, _session);
    final data = TrainingData(history: history);

    final firstPage = data.historyPage(limit: 20);
    final secondPage = data.historyPage(offset: 20, limit: 20);

    expect(firstPage, hasLength(20));
    expect(firstPage.first.id, 'session-44');
    expect(secondPage.first.id, 'session-24');
    expect(data.history, hasLength(45));
  });

  test('unconfigured builds do not claim to have a configured backend', () {
    expect(AppConfig.hasSupabaseCredentials, isFalse);
  });
}
