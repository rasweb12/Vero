import '../../measurements/domain/measurement_models.dart';
import '../../subscription/domain/app_plan.dart';
import '../../training/domain/training_models.dart';

class ProgressPoint {
  const ProgressPoint(this.date, this.value);
  final DateTime date;
  final double value;
}

DateTime monthCutoff(DateTime now, int months) {
  final first = DateTime(now.year, now.month - months, 1);
  final lastDay = DateTime(first.year, first.month + 1, 0).day;
  return DateTime(first.year, first.month, now.day.clamp(1, lastDay));
}

DateTime? periodStart(AppPlan plan, int? requestedMonths, DateTime now) =>
    plan.isPremium && requestedMonths == null
    ? null
    : monthCutoff(now, plan.isPremium ? requestedMonths! : 3);

List<ProgressPoint> metricPoints(
  MeasurementData data,
  BodyMetric metric, {
  DateTime? since,
  DateTime? until,
}) {
  // One mean per local calendar day avoids uneven weighting from duplicate entries.
  final days = <DateTime, List<double>>{};
  for (final record in data.records) {
    if ((since != null && record.date.isBefore(since)) ||
        (until != null && record.date.isAfter(until))) {
      continue;
    }
    final value = record.values[metric];
    if (value == null) continue;
    final day = DateTime(record.date.year, record.date.month, record.date.day);
    days.putIfAbsent(day, () => []).add(value);
  }
  final dates = days.keys.toList()..sort();
  return dates
      .map(
        (date) => ProgressPoint(
          date,
          days[date]!.reduce((a, b) => a + b) / days[date]!.length,
        ),
      )
      .toList();
}

List<ProgressPoint> movingAverage(
  List<ProgressPoint> points, {
  int window = 7,
}) => [
  for (var index = 0; index < points.length; index++)
    ProgressPoint(
      points[index].date,
      points
              .sublist((index - window + 1).clamp(0, index), index + 1)
              .map((point) => point.value)
              .reduce((a, b) => a + b) /
          (index + 1).clamp(1, window),
    ),
];

int? projectedDaysToGoal(List<ProgressPoint> input, double? goal) {
  if (goal == null || !goal.isFinite || input.length < 4) return null;
  final points = input.length > 14 ? input.sublist(input.length - 14) : input;
  final span = points.last.date.difference(points.first.date).inDays;
  if (span < 14) return null;
  final averages = movingAverage(points, window: 3);
  final first = averages[2];
  final last = averages.last;
  final days = last.date.difference(first.date).inDays;
  if (days <= 0) return null;
  final dailyChange = (last.value - first.value) / days;
  final distance = goal - last.value;
  if (distance.abs() < 0.1) return 0;
  if (dailyChange.abs() < 0.005 || dailyChange * distance <= 0) return null;
  final estimate = distance / dailyChange;
  if (!estimate.isFinite || estimate > 730) return null;
  return estimate.ceil();
}

List<ProgressPoint> weeklyConstancy(
  List<TrainingSession> history,
  DateTime since,
  DateTime now,
) {
  final trained = history
      .where(
        (session) =>
            session.finishedAt != null &&
            session.completedSets > 0 &&
            !session.finishedAt!.isBefore(since) &&
            !session.finishedAt!.isAfter(now),
      )
      .map((session) {
        final date = session.finishedAt!;
        return DateTime(date.year, date.month, date.day);
      })
      .toSet();
  final firstDay = DateTime(since.year, since.month, since.day);
  final firstMonday = firstDay.subtract(Duration(days: firstDay.weekday - 1));
  final end = DateTime(now.year, now.month, now.day);
  return [
    for (
      var monday = firstMonday;
      !monday.isAfter(end);
      monday = DateTime(monday.year, monday.month, monday.day + 7)
    )
      ProgressPoint(
        monday,
        trained
                .where(
                  (day) =>
                      !day.isBefore(monday) &&
                      day.isBefore(
                        DateTime(monday.year, monday.month, monday.day + 7),
                      ),
                )
                .length /
            7 *
            100,
      ),
  ];
}
