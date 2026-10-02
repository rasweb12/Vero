import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/clock_provider.dart';
import '../../../shared/utils/result.dart';
import '../../../shared/widgets/load_failure.dart';
import '../../measurements/domain/measurement_models.dart';
import '../../measurements/presentation/measurement_controller.dart';
import '../../profile/domain/usuario.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../subscription/presentation/plan_provider.dart';
import '../../training/presentation/training_controller.dart';
import '../domain/progress_assistant.dart';
import '../domain/progress_math.dart';

class ProgressPage extends ConsumerStatefulWidget {
  const ProgressPage({super.key});
  @override
  ConsumerState<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends ConsumerState<ProgressPage> {
  int? _months = 3;
  BodyMetric _metric = BodyMetric.waist;
  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(effectivePlanProvider);
    final now = ref.watch(clockProvider)();
    final since = periodStart(plan, _months, now);
    final profile = ref.watch(profileProvider).asData?.value;
    final goal = profile is Success<Usuario> ? profile.value.goalWeight : null;
    final measurements = ref.watch(measurementControllerProvider);
    final training = ref.watch(trainingControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Evolucao'),
        actions: [
          IconButton(
            tooltip: 'Fotos de progresso',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => context.pushNamed('photos'),
          ),
          IconButton(
            tooltip: 'Relatorio mensal',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => context.pushNamed('reports'),
          ),
        ],
      ),
      body: measurements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, trace) => LoadFailure(
          onRetry: () =>
              ref.read(measurementControllerProvider.notifier).reload(),
        ),
        data: (data) {
          final weight = metricPoints(
            data,
            BodyMetric.weight,
            since: since,
            until: now,
          );
          final trainingData = training.asData?.value;
          final profileUser = profile is Success<Usuario>
              ? profile.value
              : null;
          final assistantStart =
              since ??
              (trainingData == null || trainingData.history.isEmpty
                  ? monthCutoff(now, 3)
                  : trainingData.history
                        .map(
                          (session) => session.finishedAt ?? session.startedAt,
                        )
                        .reduce((a, b) => a.isBefore(b) ? a : b));
          final assistantScore = trainingData == null
              ? null
              : calculateConsistencyScore(
                  trainingData.history,
                  since: assistantStart,
                  now: now,
                  weeklyGoal: profileUser?.weeklyGoal ?? 3,
                );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (trainingData != null && assistantScore != null)
                _AssistantPanel(
                  score: assistantScore,
                  stagnation: detectStagnation(trainingData.history, now: now),
                  completedTrainings: trainingData.history.length,
                ),
              if (trainingData != null && assistantScore != null)
                const SizedBox(height: 24),
              DropdownButtonFormField<int>(
                initialValue: plan.isPremium ? (_months ?? 0) : 3,
                key: ValueKey('${plan.name}-$_months'),
                decoration: const InputDecoration(labelText: 'Periodo'),
                items: [
                  const DropdownMenuItem(value: 3, child: Text('3 meses')),
                  if (plan.isPremium) ...[
                    const DropdownMenuItem(value: 6, child: Text('6 meses')),
                    const DropdownMenuItem(value: 12, child: Text('1 ano')),
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('Todo o historico'),
                    ),
                  ],
                ],
                onChanged: (value) =>
                    setState(() => _months = value == 0 ? null : value),
              ),
              if (!plan.isPremium)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => context.pushNamed('plans'),
                    child: const Text('Ver planos para historico completo'),
                  ),
                ),
              const SizedBox(height: 24),
              Text('Peso', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Registros e media movel de ate 7 dias registrados'),
              _ProgressChart(
                key: ValueKey('weight-${since?.toIso8601String()}'),
                points: weight,
                unit: 'kg',
                average: movingAverage(weight),
                goal: goal,
              ),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _Legend(
                    color: Theme.of(context).colorScheme.primary,
                    text: 'Peso',
                  ),
                  _Legend(
                    color: Theme.of(context).colorScheme.secondary,
                    text: 'Media movel',
                  ),
                  if (goal != null)
                    const _Legend(color: Colors.deepOrange, text: 'Meta'),
                ],
              ),
              const Divider(height: 40),
              Text(
                'Constancia semanal',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text('Dias treinados / 7 · semana atual em andamento'),
              training.when(
                loading: () => const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, trace) => TextButton(
                  onPressed: () =>
                      ref.read(trainingControllerProvider.notifier).reload(),
                  child: const Text('Tentar carregar treinos'),
                ),
                data: (training) {
                  final start =
                      since ??
                      (training.history.isEmpty
                          ? monthCutoff(now, 3)
                          : training.history
                                .map(
                                  (session) =>
                                      session.finishedAt ?? session.startedAt,
                                )
                                .reduce((a, b) => a.isBefore(b) ? a : b));
                  return _ProgressChart(
                    key: ValueKey('consistency-$start'),
                    points: weeklyConstancy(training.history, start, now),
                    unit: '%',
                    percentage: true,
                  );
                },
              ),
              const Divider(height: 32),
              DropdownButtonFormField<BodyMetric>(
                initialValue: _metric,
                decoration: const InputDecoration(labelText: 'Medida corporal'),
                items: BodyMetric.values
                    .where((metric) => metric != BodyMetric.weight)
                    .map(
                      (metric) => DropdownMenuItem(
                        value: metric,
                        child: Text(metric.label),
                      ),
                    )
                    .toList(),
                onChanged: (metric) {
                  if (metric != null) setState(() => _metric = metric);
                },
              ),
              _ProgressChart(
                key: ValueKey('${_metric.name}-$since'),
                points: metricPoints(data, _metric, since: since, until: now),
                unit: 'cm',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: 12, height: 12, child: ColoredBox(color: color)),
      const SizedBox(width: 6),
      Text(text),
    ],
  );
}

class _AssistantPanel extends StatelessWidget {
  const _AssistantPanel({
    required this.score,
    required this.stagnation,
    required this.completedTrainings,
  });
  final ConsistencyScore score;
  final StagnationResult? stagnation;
  final int completedTrainings;

  @override
  Widget build(BuildContext context) {
    final celebration = celebrationForTrainingCount(completedTrainings);
    final suggestions = buildProgressSuggestions(
      consistency: score,
      stagnation: stagnation,
      completedTrainings: completedTrainings,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Seu momento',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Pontuacao de constancia: ${score.score.toStringAsFixed(0)} / 100',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('${score.trainedDays} dias treinados no periodo.'),
            if (celebration != null) ...[
              const SizedBox(height: 12),
              Text(celebration),
            ],
            if (stagnation?.isStagnant == true) ...[
              const SizedBox(height: 12),
              const Text(
                'As ultimas duas semanas ficaram estaveis. Vale observar descanso e carga com calma.',
              ),
            ],
            const SizedBox(height: 12),
            Text(suggestions.first),
          ],
        ),
      ),
    );
  }
}

class _ProgressChart extends StatelessWidget {
  const _ProgressChart({
    required this.points,
    required this.unit,
    this.average = const [],
    this.goal,
    this.percentage = false,
    super.key,
  });
  final List<ProgressPoint> points;
  final List<ProgressPoint> average;
  final String unit;
  final double? goal;
  final bool percentage;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: Text('Ainda sem registros neste periodo.')),
      );
    }
    final values = [...points.map((point) => point.value), ?goal];
    final low = values.reduce(math.min);
    final high = values.reduce(math.max);
    final padding = math.max((high - low) * 0.15, 1.0);
    final minY = percentage ? 0.0 : math.max(0.0, low - padding);
    final maxY = percentage ? 100.0 : high + padding;
    final first = points.first.date;
    double x(DateTime date) => date.difference(first).inHours / 24;
    final maxX = math.max(1.0, x(points.last.date));
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: SizedBox(
        height: 250,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, factor, child) => LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 4,
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 46,
                    interval: (maxY - minY) / 4,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(percentage ? 0 : 1),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: math.max(1.0, maxX / 3),
                    getTitlesWidget: (value, meta) {
                      final date = first.add(
                        Duration(hours: (value * 24).round()),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${date.day}/${date.month}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (goal != null)
                    HorizontalLine(
                      y: goal!,
                      color: Colors.deepOrange,
                      strokeWidth: 1.5,
                      dashArray: [5, 5],
                    ),
                ],
              ),
              lineTouchData: LineTouchData(
                enabled: factor == 1,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((spot) {
                    final date = first.add(
                      Duration(hours: (spot.x * 24).round()),
                    );
                    return LineTooltipItem(
                      '${date.day}/${date.month}\n${spot.y.toStringAsFixed(1)} $unit',
                      const TextStyle(color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: points
                      .map(
                        (point) => FlSpot(
                          x(point.date),
                          minY + (point.value - minY) * factor,
                        ),
                      )
                      .toList(),
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 2.5,
                  isCurved: !percentage,
                  preventCurveOverShooting: true,
                  dotData: FlDotData(show: points.length <= 14),
                ),
                if (average.isNotEmpty)
                  LineChartBarData(
                    spots: average
                        .map(
                          (point) => FlSpot(
                            x(point.date),
                            minY + (point.value - minY) * factor,
                          ),
                        )
                        .toList(),
                    color: Theme.of(context).colorScheme.secondary,
                    barWidth: 2,
                    isCurved: true,
                    preventCurveOverShooting: true,
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
            duration: Duration.zero,
          ),
        ),
      ),
    );
  }
}
