import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/exercise_library.dart';
import '../domain/training_models.dart';
import 'training_controller.dart';
import 'training_widgets.dart';

class TrainingPage extends ConsumerWidget {
  const TrainingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(trainingControllerProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Treinos'),
          actions: [
            IconButton(
              tooltip: 'Biblioteca de exercicios',
              icon: const Icon(Icons.menu_book_outlined),
              onPressed: () => context.pushNamed('exercises'),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Rotinas'),
              Tab(text: 'Historico'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Criar treino',
          onPressed: () => context.pushNamed('new-training'),
          child: const Icon(Icons.add),
        ),
        body: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, trace) => TrainingError(
            onRetry: () =>
                ref.read(trainingControllerProvider.notifier).reload(),
          ),
          data: (data) => TabBarView(
            children: [_routines(context, ref, data), _history(context, data)],
          ),
        ),
      ),
    );
  }

  Widget _routines(
    BuildContext context,
    WidgetRef ref,
    TrainingData data,
  ) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
    children: [
      if (data.active != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.play_circle_outline),
          title: Text(data.active!.routine.name),
          subtitle: const Text('Treino em andamento'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.pushNamed('active-training'),
        ),
      if (data.routines.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Text(
            'Suas rotinas comecam aqui. Crie seu primeiro treino.',
            textAlign: TextAlign.center,
          ),
        ),
      for (final routine in data.routines)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          routine.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar ${routine.name}',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => context.pushNamed(
                          'edit-training',
                          pathParameters: {'id': routine.id},
                        ),
                      ),
                      IconButton(
                        tooltip: 'Excluir ${routine.name}',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Excluir rotina?'),
                              content: const Text(
                                'O historico e o treino em andamento serao mantidos.',
                              ),
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
                              .read(trainingControllerProvider.notifier)
                              .deleteRoutine(routine.id);
                          if (context.mounted) {
                            showTrainingResult(context, result);
                          }
                        },
                      ),
                    ],
                  ),
                  Text(
                    '${routine.exercises.length} exercicios · ${routine.exercises.fold<int>(0, (count, exercise) => count + exercise.sets.length)} series',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    routine.exercises
                        .map(
                          (exercise) => exerciseById(exercise.exerciseId).name,
                        )
                        .join(', '),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Iniciar treino'),
                    onPressed: data.active != null
                        ? null
                        : () async {
                            final result = await ref
                                .read(trainingControllerProvider.notifier)
                                .start(routine.id);
                            if (!context.mounted) return;
                            showTrainingResult(context, result);
                            if (result.isSuccess) {
                              await context.pushNamed('active-training');
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _history(BuildContext context, TrainingData data) {
    if (data.history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Seu primeiro treino concluido aparecera aqui.'),
        ),
      );
    }
    return _HistoryList(data: data);
  }
}

class _HistoryList extends StatefulWidget {
  const _HistoryList({required this.data});
  final TrainingData data;

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  static const _pageSize = 20;
  int _visible = _pageSize;

  @override
  void didUpdateWidget(covariant _HistoryList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.history.length != widget.data.history.length) {
      _visible = _pageSize;
    }
  }

  void _loadNextPage() {
    if (_visible >= widget.data.history.length) return;
    setState(() => _visible += _pageSize);
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.data.historyPage(limit: _visible);
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 320) _loadNextPage();
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: sessions.length,
        itemBuilder: (context, index) {
          final session = sessions[index];
          final minutes = session.finishedAt!
              .difference(session.startedAt)
              .inMinutes;
          return ListTile(
            leading: const Icon(Icons.check_circle_outline),
            title: Text(session.routine.name),
            subtitle: Text(
              '${formatDate(session.finishedAt!)} · $minutes min · ${session.completedSets}/${session.totalSets} series',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed(
              'training-history',
              pathParameters: {'id': session.id},
            ),
          );
        },
      ),
    );
  }
}

class HistoryDetailPage extends ConsumerWidget {
  const HistoryDetailPage({required this.id, super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Treino concluido')),
    body: ref
        .watch(trainingControllerProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, trace) => TrainingError(
            onRetry: () =>
                ref.read(trainingControllerProvider.notifier).reload(),
          ),
          data: (data) {
            final session = data.history
                .where((item) => item.id == id)
                .firstOrNull;
            if (session == null) {
              return const Center(child: Text('Registro nao encontrado.'));
            }
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  session.routine.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  '${formatDate(session.finishedAt!)} · ${session.completedSets} series concluidas',
                ),
                const SizedBox(height: 24),
                for (final exercise in session.routine.exercises) ...[
                  Text(
                    exerciseById(exercise.exerciseId).name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final (index, set) in exercise.sets.indexed)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        set.completed
                            ? Icons.check_circle_outline
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(
                        'Serie ${index + 1}: ${set.reps} reps · ${formatWeight(set.weight)} kg',
                      ),
                      subtitle: set.completed
                          ? null
                          : const Text('Nao concluida'),
                    ),
                  const Divider(height: 32),
                ],
              ],
            );
          },
        ),
  );
}
