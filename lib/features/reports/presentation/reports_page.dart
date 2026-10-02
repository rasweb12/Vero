import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/utils/result.dart';
import '../../measurements/domain/measurement_models.dart';
import '../../measurements/presentation/measurement_controller.dart';
import '../../profile/domain/usuario.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../progress/domain/progress_assistant.dart';
import '../../subscription/presentation/plan_provider.dart';
import '../../training/domain/training_models.dart';
import '../../training/presentation/training_controller.dart';
import '../data/report_service.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  bool _busy = false;
  final _service = ReportService();

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(effectivePlanProvider).isPremium) {
      return Scaffold(
        appBar: AppBar(title: const Text('Relatorio')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 40),
                const SizedBox(height: 16),
                const Text(
                  'Relatorios sao um recurso Premium.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.pushNamed('plans'),
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: const Text('Ver planos'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final profile = ref.watch(profileProvider).asData?.value;
    final measurements = ref.watch(measurementControllerProvider).asData?.value;
    final training = ref.watch(trainingControllerProvider).asData?.value;
    final user = profile is Success<Usuario> ? profile.value : null;
    if (user == null || measurements == null || training == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Relatorio')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final snapshot = _snapshot(user, measurements, training);
    return Scaffold(
      appBar: AppBar(title: const Text('Relatorio mensal')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Uma leitura leve da sua evolucao',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(snapshot.periodLabel),
          const SizedBox(height: 24),
          _Summary(snapshot: snapshot),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : () => _sharePdf(snapshot),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(
              _busy ? 'Preparando...' : 'Exportar e compartilhar PDF',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _shareImage(snapshot),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('Compartilhar imagem de progresso'),
          ),
        ],
      ),
    );
  }

  ReportSnapshot _snapshot(
    Usuario user,
    MeasurementData measurements,
    TrainingData training,
  ) {
    final now = DateTime.now();
    final since = DateTime(now.year, now.month - 1, now.day);
    final history = training.history.where((session) {
      final date = session.finishedAt;
      return date != null && !date.isBefore(since) && !date.isAfter(now);
    }).toList();
    final score = calculateConsistencyScore(
      training.history,
      since: since,
      now: now,
      weeklyGoal: user.weeklyGoal,
    );
    final weight = metricPointsForReport(
      measurements,
      BodyMetric.weight,
      since,
      now,
    );
    final changes = <ReportMeasurementChange>[];
    for (final metric in measurements.selected.where(
      (item) => item != BodyMetric.weight,
    )) {
      final points = metricPointsForReport(measurements, metric, since, now);
      if (points.length >= 2) {
        changes.add(
          ReportMeasurementChange(
            label: metric.label,
            unit: metric.unit,
            change: points.last - points.first,
          ),
        );
      }
    }
    return ReportSnapshot(
      userName: user.name,
      periodLabel: 'Ultimos 30 dias',
      consistencyScore: score.score,
      trainingCount: history.length,
      totalVolume: history.fold(0, (total, session) => total + session.volume),
      weightStart: weight.length < 2 ? null : weight.first,
      weightEnd: weight.length < 2 ? null : weight.last,
      goalWeight: user.goalWeight,
      measurementChanges: changes,
    );
  }

  List<double> metricPointsForReport(
    MeasurementData data,
    BodyMetric metric,
    DateTime since,
    DateTime now,
  ) {
    final days = <DateTime, List<double>>{};
    for (final record in data.records) {
      if (record.date.isBefore(since) || record.date.isAfter(now)) continue;
      final value = record.values[metric];
      if (value == null) continue;
      final date = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      days.putIfAbsent(date, () => []).add(value);
    }
    final dates = days.keys.toList()..sort();
    return dates.map((date) {
      final values = days[date]!;
      return values.reduce((a, b) => a + b) / values.length;
    }).toList();
  }

  Future<void> _sharePdf(ReportSnapshot snapshot) async {
    setState(() => _busy = true);
    try {
      await Printing.sharePdf(
        bytes: await _service.buildPdf(snapshot),
        filename: 'vero-relatorio.pdf',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareImage(ReportSnapshot snapshot) async {
    setState(() => _busy = true);
    try {
      final bytes = await _service.buildShareImage(snapshot);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'vero-progresso.png',
            ),
          ],
          text: 'Meu progresso no Vero',
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.snapshot});
  final ReportSnapshot snapshot;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _line(
            'Constancia',
            '${snapshot.consistencyScore.toStringAsFixed(0)} / 100',
          ),
          _line('Treinos', '${snapshot.trainingCount}'),
          _line('Volume', '${snapshot.totalVolume.toStringAsFixed(1)} kg'),
        ],
      ),
    ),
  );

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );
}
