import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/exercise_library.dart';
import '../domain/training_models.dart';
import 'exercise_animation_player.dart';
import 'exercise_providers.dart';
import 'training_controller.dart';

class ExerciseDetailContext {
  const ExerciseDetailContext({
    required this.exercise,
    this.restSeconds,
    this.returnToWorkout = false,
  });
  final ExercicioTreino exercise;
  final int? restSeconds;
  final bool returnToWorkout;
}

Future<void> openExerciseDetail(
  BuildContext context,
  ExercicioTreino exercise, {
  int? restSeconds,
  bool returnToWorkout = false,
}) async {
  await context.pushNamed(
    'exercise-detail',
    pathParameters: {'id': exercise.exerciseId},
    extra: ExerciseDetailContext(
      exercise: exercise,
      restSeconds: restSeconds,
      returnToWorkout: returnToWorkout,
    ),
  );
}

class ExerciseDetailPage extends ConsumerWidget {
  const ExerciseDetailPage({required this.id, this.workout, super.key});
  final String id;
  final ExerciseDetailContext? workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(exerciseCatalogProvider);
    final custom =
        ref.watch(trainingControllerProvider).asData?.value.customExercises ??
        const <Exercicio>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Como executar')),
      body: SafeArea(
        child: catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, trace) => Center(
            child: TextButton.icon(
              onPressed: () => ref.invalidate(exerciseCatalogProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Reabrir biblioteca'),
            ),
          ),
          data: (items) {
            final exercise = exerciseById(
              id,
              catalog: items,
              customExercises: custom,
            );
            final prescription = workout?.exercise.exerciseId == id
                ? workout
                : null;
            final alternatives = exercise.alternatives
                .map(
                  (alternativeId) => [...custom, ...items]
                      .where(
                        (item) =>
                            item.id == alternativeId &&
                            item.id != id &&
                            item.isActive,
                      )
                      .firstOrNull,
                )
                .whereType<Exercicio>()
                .toList();
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      exercise.name,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${exercise.muscleGroup} · ${exercise.difficulty.label}',
                    ),
                    const SizedBox(height: 20),
                    ExerciseAnimationPlayer(
                      key: ValueKey(exercise.media),
                      media: exercise.media,
                      description: exercise.description,
                    ),
                    const SizedBox(height: 16),
                    if (exercise.description.isNotEmpty)
                      Text(
                        exercise.description,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    _section(context, 'Musculos trabalhados', [
                      exercise.primaryMuscle.isEmpty
                          ? exercise.muscleGroup
                          : exercise.primaryMuscle,
                      ...exercise.secondaryMuscles,
                    ]),
                    if (prescription != null) ...[
                      const Divider(height: 32),
                      Text(
                        '${prescription.exercise.sets.length} series',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final (index, set)
                          in prescription.exercise.sets.indexed)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Serie ${index + 1}: ${set.reps} repeticoes · ${set.weight.toStringAsFixed(set.weight == set.weight.roundToDouble() ? 0 : 1).replaceAll('.', ',')} kg',
                          ),
                        ),
                      if (prescription.restSeconds != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Repouso: ${prescription.restSeconds} segundos',
                          ),
                        ),
                      if (prescription.exercise.intensityTechnique
                          case final String technique when technique.isNotEmpty)
                        _section(context, 'Tecnica de intensidade', [
                          technique,
                        ]),
                      if (prescription.exercise.notes case final String notes
                          when notes.isNotEmpty)
                        _section(context, 'Notas da ficha', [notes]),
                    ],
                    _section(
                      context,
                      'Execucao',
                      exercise.instructions.isEmpty
                          ? [
                              'Orientacoes em preparacao. Procure orientacao profissional para este movimento.',
                            ]
                          : exercise.instructions,
                      numbered: true,
                    ),
                    _section(
                      context,
                      'Erros comuns',
                      exercise.commonErrors.isEmpty
                          ? ['Orientacoes em preparacao.']
                          : exercise.commonErrors,
                      icon: Icons.warning_amber_outlined,
                      warning: true,
                    ),
                    _section(
                      context,
                      'Seguranca',
                      exercise.safetyTips.isEmpty
                          ? [
                              'Utilize uma carga que permita manter o controle do movimento.',
                              'Interrompa em caso de dor aguda. Na duvida, procure orientacao profissional.',
                            ]
                          : exercise.safetyTips,
                      icon: Icons.check_circle_outline,
                    ),
                    _section(context, 'Equipamento', exercise.equipmentNames),
                    if (alternatives.isNotEmpty) ...[
                      const Divider(height: 32),
                      Text(
                        'Alternativas',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      for (final alternative in alternatives)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(alternative.name),
                          subtitle: Text(
                            alternative.equipmentNames.join(' + '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.pushNamed(
                            'exercise-detail',
                            pathParameters: {'id': alternative.id},
                          ),
                        ),
                    ],
                    if (prescription?.returnToWorkout == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Voltar ao treino'),
                          onPressed: () => context.pop(),
                        ),
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

  Widget _section(
    BuildContext context,
    String title,
    List<String> lines, {
    bool numbered = false,
    IconData? icon,
    bool warning = false,
  }) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 8),
        for (final (index, line) in lines.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (numbered) SizedBox(width: 28, child: Text('${index + 1}.')),
                if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      icon,
                      size: 20,
                      color: warning
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                Expanded(
                  child: Text(
                    line,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
