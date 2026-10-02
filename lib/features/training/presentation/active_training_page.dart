import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../notifications/presentation/notification_controller.dart';
import '../domain/exercise_library.dart';
import '../domain/training_models.dart';
import 'training_controller.dart';
import 'training_widgets.dart';

int remainingRestSeconds(DateTime? deadline, DateTime now) => deadline == null
    ? 0
    : (deadline.difference(now).inMilliseconds / 1000).ceil().clamp(0, 600);

class ActiveTrainingPage extends ConsumerStatefulWidget {
  const ActiveTrainingPage({super.key});
  @override
  ConsumerState<ActiveTrainingPage> createState() => _ActiveTrainingPageState();
}

class _ActiveTrainingPageState extends ConsumerState<ActiveTrainingPage> {
  Timer? _ticker;
  DateTime? _notifiedDeadline;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final deadline = ref
          .read(trainingControllerProvider)
          .asData
          ?.value
          .active
          ?.restEndsAt;
      if (deadline != null &&
          !deadline.isAfter(DateTime.now()) &&
          deadline != _notifiedDeadline) {
        _notifiedDeadline = deadline;
        unawaited(HapticFeedback.vibrate());
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _finish(TrainingSession session) async {
    if (_finishing) return;
    if (session.completedSets < session.totalSets) {
      final finish = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Finalizar por hoje?'),
          content: Text(
            '${session.completedSets} de ${session.totalSets} series concluidas. Seu progresso sera salvo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Finalizar'),
            ),
          ],
        ),
      );
      if (finish != true || !mounted) return;
    }
    setState(() => _finishing = true);
    final result = await ref.read(trainingControllerProvider.notifier).finish();
    if (!mounted) return;
    setState(() => _finishing = false);
    showTrainingResult(context, result);
    if (result.isSuccess) {
      unawaited(
        ref
            .read(notificationControllerProvider.notifier)
            .recordTrainingFinished(DateTime.now()),
      );
      context.goNamed('training-history', pathParameters: {'id': session.id});
    }
  }

  Future<void> _discard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar este treino?'),
        content: const Text(
          'As series desta sessao nao entrarao no historico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar treino'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    final result = await ref
        .read(trainingControllerProvider.notifier)
        .discard();
    if (!mounted) return;
    showTrainingResult(context, result);
    if (result.isSuccess) context.goNamed('training');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Em treino'),
      leading: IconButton(
        tooltip: 'Voltar e manter treino',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.goNamed('training'),
      ),
      actions: [
        IconButton(
          tooltip: 'Descartar treino',
          icon: const Icon(Icons.close),
          onPressed: _finishing ? null : _discard,
        ),
      ],
    ),
    body: SafeArea(
      child: ref
          .watch(trainingControllerProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, trace) => TrainingError(
              onRetry: () =>
                  ref.read(trainingControllerProvider.notifier).reload(),
            ),
            data: (data) {
              final session = data.active;
              if (session == null) {
                return Center(
                  child: TextButton(
                    onPressed: () => context.goNamed('training'),
                    child: const Text('Voltar aos treinos'),
                  ),
                );
              }
              final remaining = remainingRestSeconds(
                session.restEndsAt,
                DateTime.now(),
              );
              final minutes = DateTime.now()
                  .difference(session.startedAt)
                  .inMinutes;
              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.restEndsAt == null
                                    ? 'No seu ritmo'
                                    : remaining > 0
                                    ? 'Repouso'
                                    : 'Repouso concluido',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${session.completedSets}/${session.totalSets} series · $minutes min',
                              ),
                            ],
                          ),
                        ),
                        if (session.restEndsAt != null)
                          Text(
                            '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        if (remaining > 0)
                          IconButton(
                            tooltip: 'Pular repouso',
                            icon: const Icon(Icons.skip_next),
                            onPressed: () async {
                              final result = await ref
                                  .read(trainingControllerProvider.notifier)
                                  .clearRest();
                              if (context.mounted) {
                                showTrainingResult(context, result);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          session.routine.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 24),
                        for (final (exerciseIndex, exercise)
                            in session.routine.exercises.indexed) ...[
                          Text(
                            exerciseById(exercise.exerciseId).name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          for (final (setIndex, set) in exercise.sets.indexed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _ActiveSet(
                                key: ValueKey(
                                  '${session.id}-$exerciseIndex-$setIndex',
                                ),
                                exerciseIndex: exerciseIndex,
                                setIndex: setIndex,
                                set: set,
                                previous: previousSet(
                                  data,
                                  exercise.exerciseId,
                                  setIndex,
                                ),
                                disabled: _finishing,
                              ),
                            ),
                          const SizedBox(height: 12),
                        ],
                        ElevatedButton.icon(
                          onPressed: _finishing || session.completedSets == 0
                              ? null
                              : () => _finish(session),
                          icon: const Icon(Icons.done_all),
                          label: Text(
                            _finishing ? 'Salvando...' : 'Finalizar treino',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
    ),
  );
}

class _ActiveSet extends ConsumerStatefulWidget {
  const _ActiveSet({
    required this.exerciseIndex,
    required this.setIndex,
    required this.set,
    required this.previous,
    required this.disabled,
    super.key,
  });
  final int exerciseIndex;
  final int setIndex;
  final Serie set;
  final PreviousSet? previous;
  final bool disabled;
  @override
  ConsumerState<_ActiveSet> createState() => _ActiveSetState();
}

class _ActiveSetState extends ConsumerState<_ActiveSet> {
  bool _busy = false;
  Future<void> _adjust({
    int reps = 0,
    double weight = 0,
    bool? completed,
  }) async {
    if (_busy || widget.disabled) return;
    setState(() => _busy = true);
    final result = await ref
        .read(trainingControllerProvider.notifier)
        .adjustSet(
          widget.exerciseIndex,
          widget.setIndex,
          reps: reps,
          weight: weight,
          completed: completed,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    showTrainingResult(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final previous = widget.previous;
    final delta = previous == null
        ? 0.0
        : widget.set.weight - previous.set.weight;
    final days = previous == null
        ? 0
        : DateTime.now().difference(previous.date).inDays;
    final enabled = !_busy && !widget.disabled;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Serie ${widget.setIndex + 1}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (previous != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  '${delta > 0 ? '+' : ''}${formatWeight(delta)} kg vs ${days == 0 ? 'hoje' : 'ha $days dias'} · antes ${previous.set.reps} reps',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            _Stepper(
              label: 'Reps',
              value: '${widget.set.reps}',
              onMinus: !enabled || widget.set.reps <= 1
                  ? null
                  : () => _adjust(reps: -1),
              onPlus: !enabled || widget.set.reps >= 999
                  ? null
                  : () => _adjust(reps: 1),
            ),
            _Stepper(
              label: 'Kg',
              value: formatWeight(widget.set.weight),
              onMinus: !enabled || widget.set.weight <= 0
                  ? null
                  : () => _adjust(weight: -2.5),
              onPlus: !enabled || widget.set.weight >= 1000
                  ? null
                  : () => _adjust(weight: 2.5),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: enabled
                  ? () => _adjust(completed: !widget.set.completed)
                  : null,
              icon: Icon(
                widget.set.completed
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
              ),
              label: Text(
                widget.set.completed ? 'Concluida' : 'Concluir serie',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    this.onMinus,
    this.onPlus,
  });
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        tooltip: 'Diminuir $label',
        onPressed: onMinus,
        icon: const Icon(Icons.remove),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      ),
      SizedBox(
        width: 72,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: Theme.of(context).textTheme.headlineMedium),
        ),
      ),
      IconButton(
        tooltip: 'Aumentar $label',
        onPressed: onPlus,
        icon: const Icon(Icons.add),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      ),
    ],
  );
}
