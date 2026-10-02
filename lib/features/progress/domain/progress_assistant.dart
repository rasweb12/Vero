import 'dart:math' as math;

import '../../training/domain/training_models.dart';

class ConsistencyScore {
  const ConsistencyScore({
    required this.score,
    required this.trainedDays,
    required this.periodDays,
    required this.weeklyConsistency,
  });

  final double score;
  final int trainedDays;
  final int periodDays;
  final double weeklyConsistency;
}

ConsistencyScore calculateConsistencyScore(
  List<TrainingSession> history, {
  required DateTime since,
  required DateTime now,
  int weeklyGoal = 3,
}) {
  final start = DateTime(since.year, since.month, since.day);
  final end = DateTime(now.year, now.month, now.day);
  final periodDays = math.max(1, end.difference(start).inDays + 1);
  final trained = history
      .where(
        (session) =>
            session.finishedAt != null &&
            session.completedSets > 0 &&
            !session.finishedAt!.isBefore(start) &&
            !session.finishedAt!.isAfter(now),
      )
      .map((session) {
        final date = session.finishedAt!;
        return DateTime(date.year, date.month, date.day);
      })
      .toSet();
  final weeks = math.max(1, (periodDays / 7).ceil());
  final target = math.max(1, weeklyGoal) * weeks;
  final weeklyConsistency = (trained.length / target).clamp(0.0, 1.0);
  final score = (trained.length / periodDays) * weeklyConsistency * 100;
  return ConsistencyScore(
    score: score.clamp(0, 100).toDouble(),
    trainedDays: trained.length,
    periodDays: periodDays,
    weeklyConsistency: weeklyConsistency,
  );
}

class StagnationResult {
  const StagnationResult({
    required this.isStagnant,
    required this.recentAverage,
    required this.previousAverage,
    required this.daysWithoutEvolution,
  });

  final bool isStagnant;
  final double recentAverage;
  final double previousAverage;
  final int daysWithoutEvolution;
}

StagnationResult? detectStagnation(
  List<TrainingSession> history, {
  required DateTime now,
}) {
  final sessions =
      history
          .where(
            (session) =>
                session.finishedAt != null && session.completedSets > 0,
          )
          .toList()
        ..sort((a, b) => a.finishedAt!.compareTo(b.finishedAt!));
  if (sessions.length < 8) return null;
  final recent = sessions.sublist(sessions.length - 4);
  final previous = sessions.sublist(sessions.length - 8, sessions.length - 4);
  final recentAverage = _average(recent.map((session) => session.volume));
  final previousAverage = _average(previous.map((session) => session.volume));
  final lastProgress = recent
      .where((session) => session.volume > previousAverage * 1.02)
      .map((session) => session.finishedAt!)
      .fold<DateTime?>(null, (latest, date) {
        if (latest == null || date.isAfter(latest)) return date;
        return latest;
      });
  final days = lastProgress == null
      ? now.difference(recent.last.finishedAt!).inDays
      : now.difference(lastProgress).inDays;
  return StagnationResult(
    isStagnant: days >= 14 && recentAverage <= previousAverage * 1.02,
    recentAverage: recentAverage,
    previousAverage: previousAverage,
    daysWithoutEvolution: math.max(0, days),
  );
}

double _average(Iterable<double> values) {
  final list = values.toList();
  if (list.isEmpty) return 0;
  return list.reduce((a, b) => a + b) / list.length;
}

String? celebrationForTrainingCount(int count) => switch (count) {
  1 => 'Primeiro treino concluido. A constancia comeca assim.',
  5 => 'Cinco treinos concluidos. Voce esta construindo um ritmo.',
  10 => 'Dez treinos concluidos. Seu esforco ja virou historia.',
  25 => 'Vinte e cinco treinos. Um marco consistente.',
  _ => null,
};

List<String> buildProgressSuggestions({
  required ConsistencyScore consistency,
  required StagnationResult? stagnation,
  required int completedTrainings,
}) {
  final suggestions = <String>[];
  if (consistency.score < 30) {
    suggestions.add('Escolha um dia simples para voltar ao seu ritmo.');
  } else if (consistency.score < 65) {
    suggestions.add('Seu ritmo esta se formando. Uma sessao curta ja conta.');
  } else {
    suggestions.add(
      'Sua constancia esta forte. Preserve o ritmo que funciona.',
    );
  }
  if (stagnation?.isStagnant == true) {
    suggestions.add(
      'As ultimas duas semanas ficaram estaveis. Considere rever descanso ou carga com calma.',
    );
  }
  if (completedTrainings == 0) {
    suggestions.add(
      'Registre seu primeiro treino para comecar a comparar sua evolucao.',
    );
  }
  return suggestions;
}
