import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/result.dart';
import '../../../shared/widgets/load_failure.dart';
import '../../profile/domain/usuario.dart';
import '../../profile/presentation/profile_providers.dart';
import '../../progress/domain/progress_math.dart';
import '../../subscription/domain/app_plan.dart';
import '../../subscription/presentation/plan_provider.dart';
import '../../training/presentation/training_widgets.dart';
import '../domain/measurement_models.dart';
import 'measurement_controller.dart';

class MeasurementsPage extends ConsumerWidget {
  const MeasurementsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(effectivePlanProvider);
    final profile = ref.watch(profileProvider).asData?.value;
    final goal = profile is Success<Usuario> ? profile.value.goalWeight : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medidas'),
        actions: [
          IconButton(
            tooltip: 'Evolucao',
            icon: const Icon(Icons.show_chart),
            onPressed: () => context.pushNamed('progress'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Registrar medidas',
        onPressed: () => context.pushNamed('new-measurement'),
        child: const Icon(Icons.add),
      ),
      body: ref
          .watch(measurementControllerProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, trace) => LoadFailure(
              onRetry: () =>
                  ref.read(measurementControllerProvider.notifier).reload(),
            ),
            data: (data) {
              final metrics = data.allowedMetrics(plan.measurementLimit);
              final estimate = projectedDaysToGoal(
                metricPoints(data, BodyMetric.weight),
                goal,
              );
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Seus registros',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Escolher medidas',
                        icon: const Icon(Icons.tune),
                        onPressed: () async {
                          final selected = await showDialog<List<BodyMetric>>(
                            context: context,
                            builder: (_) =>
                                _MetricDialog(selected: metrics, plan: plan),
                          );
                          if (selected == null) return;
                          final result = await ref
                              .read(measurementControllerProvider.notifier)
                              .selectMetrics(selected);
                          if (context.mounted) {
                            showTrainingResult(context, result);
                          }
                        },
                      ),
                    ],
                  ),
                  for (final metric in metrics)
                    Builder(
                      builder: (context) {
                        final records = data.forMetric(metric);
                        final current = records.lastOrNull;
                        final value = current?.values[metric];
                        final difference = records.length < 2
                            ? null
                            : value! -
                                  records[records.length - 2].values[metric]!;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(metric.label),
                          subtitle: Text(
                            current == null
                                ? 'Ainda sem registro'
                                : '${formatDate(current.date)}${difference == null ? '' : ' · ${difference > 0 ? '+' : ''}${formatWeight(difference)} ${metric.unit} vs anterior'}',
                          ),
                          trailing: Text(
                            value == null
                                ? '--'
                                : '${formatWeight(value)} ${metric.unit}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        );
                      },
                    ),
                  const Divider(height: 32),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Meta de peso'),
                    subtitle: Text(
                      goal == null
                          ? 'Defina uma meta no seu perfil.'
                          : '${formatWeight(goal)} kg',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => context.goNamed('profile'),
                  ),
                  Text(
                    estimate == 0
                        ? 'Seus registros recentes estao proximos da meta.'
                        : estimate == null
                        ? 'Ainda sem tendencia suficiente para estimar uma data.'
                        : 'Mantida a tendencia recente: aproximadamente $estimate dias. Esta estimativa pode mudar.',
                  ),
                  const Divider(height: 32),
                  Text(
                    'Historico',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (data.records.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Registre suas primeiras medidas no seu tempo.',
                      ),
                    ),
                  for (final record in data.records.reversed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(formatDate(record.date)),
                      subtitle: Text(
                        '${record.values.entries.map((entry) => '${entry.key.label}: ${formatWeight(entry.value)} ${entry.key.unit}').join(' · ')}${record.notes.isEmpty ? '' : '\n${record.notes}'}',
                      ),
                      trailing: IconButton(
                        tooltip:
                            'Excluir registro de ${formatDate(record.date)}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Excluir registro?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Excluir'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true) return;
                          final result = await ref
                              .read(measurementControllerProvider.notifier)
                              .deleteRecord(record.id);
                          if (context.mounted) {
                            showTrainingResult(context, result);
                          }
                        },
                      ),
                    ),
                ],
              );
            },
          ),
    );
  }
}

class _MetricDialog extends StatefulWidget {
  const _MetricDialog({required this.selected, required this.plan});
  final List<BodyMetric> selected;
  final AppPlan plan;
  @override
  State<_MetricDialog> createState() => _MetricDialogState();
}

class _MetricDialogState extends State<_MetricDialog> {
  late final Set<BodyMetric> _selected = widget.selected.toSet();
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.plan.isPremium
          ? 'Escolher medidas'
          : 'Medidas (${_selected.length}/5)',
    ),
    content: SizedBox(
      width: 360,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final metric in BodyMetric.values)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(metric.label),
                value: _selected.contains(metric),
                onChanged:
                    !_selected.contains(metric) &&
                        !widget.plan.isPremium &&
                        _selected.length >= 5
                    ? null
                    : (selected) => setState(() {
                        if (selected == true) {
                          _selected.add(metric);
                        } else {
                          _selected.remove(metric);
                        }
                      }),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      TextButton(
        onPressed: _selected.isEmpty
            ? null
            : () => Navigator.pop(context, _selected.toList()),
        child: const Text('Salvar'),
      ),
    ],
  );
}
