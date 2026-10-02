import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_controller.dart';
import '../../training/presentation/training_controller.dart';
import '../../training/presentation/training_widgets.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authControllerProvider).account;
    return Scaffold(
      appBar: AppBar(title: const Text('Vero')),
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
                final next = data.nextRoutine;
                final trained = data.trainedDaysThisWeek(DateTime.now());
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          account?.name.isNotEmpty == true
                              ? 'Ola, ${account!.name}.'
                              : 'Seu ritmo. Seus resultados.',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cada vez que voce volta, sua historia continua.',
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Sua semana',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$trained ${trained == 1 ? 'dia treinado' : 'dias treinados'}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: trained / 7,
                          minHeight: 6,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(trained / 7 * 100).round()}% dos dias da semana · constancia, sem perfeicao.',
                        ),
                        const Divider(height: 48),
                        if (data.active != null) ...[
                          Text(
                            'Continue de onde parou',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(data.active!.routine.name),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () =>
                                context.pushNamed('active-training'),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Retomar treino'),
                          ),
                        ] else if (next != null) ...[
                          Text(
                            'Proximo treino',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            next.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text('${next.exercises.length} exercicios'),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Comecar treino'),
                            onPressed: () async {
                              final result = await ref
                                  .read(trainingControllerProvider.notifier)
                                  .start(next.id);
                              if (!context.mounted) return;
                              showTrainingResult(context, result);
                              if (result.isSuccess) {
                                await context.pushNamed('active-training');
                              }
                            },
                          ),
                        ] else ...[
                          Text(
                            'Seu primeiro treino',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context.pushNamed('new-training'),
                            icon: const Icon(Icons.add),
                            label: const Text('Criar rotina'),
                          ),
                        ],
                        const Divider(height: 48),
                        Text(
                          'Ate aqui',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${data.history.length} treinos concluidos · ${data.routines.length} rotinas',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      ),
    );
  }
}
