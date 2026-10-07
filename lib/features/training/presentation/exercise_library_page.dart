import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/exercise_library.dart';
import '../domain/training_models.dart';
import 'custom_exercise_page.dart';
import 'exercise_providers.dart';
import 'training_controller.dart';
import 'training_widgets.dart';

class ExerciseLibraryPage extends ConsumerStatefulWidget {
  const ExerciseLibraryPage({
    this.select = false,
    this.excluded = const {},
    super.key,
  });
  final bool select;
  final Set<String> excluded;
  @override
  ConsumerState<ExerciseLibraryPage> createState() =>
      _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends ConsumerState<ExerciseLibraryPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  String? _group;
  String? _equipment;
  ExerciseDifficulty? _difficulty;
  bool _refreshing = false;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final exercise = await Navigator.of(context).push<Exercicio>(
      MaterialPageRoute(
        builder: (_) => CustomExercisePage(
          initialMuscleGroup: _group,
          initialName: _query.trim(),
        ),
      ),
    );
    if (!mounted || exercise == null) return;
    if (widget.select) {
      Navigator.of(context).pop(exercise);
      return;
    }
    setState(() {
      _search.clear();
      _query = '';
      _group = exercise.muscleGroup;
      _equipment = null;
      _difficulty = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final result = await refreshExerciseCatalog(ref);
    if (!mounted) return;
    setState(() => _refreshing = false);
    showTrainingResult(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final training = ref.watch(trainingControllerProvider);
    final library = ref.watch(exerciseCatalogProvider);
    final data = training.asData?.value;
    final catalog = [
      ...?data?.customExercises.reversed,
      ...?library.asData?.value,
    ];
    final groups = {
      ...exerciseMuscleGroups,
      ...catalog.map((exercise) => exercise.muscleGroup),
    }.toList();
    final equipment = {
      ...exerciseEquipmentTypes,
      ...catalog.expand((exercise) => exercise.equipmentNames),
    }.toList()..sort();
    final exercises = filterExercises(
      catalog,
      query: _query,
      muscleGroup: _group,
      equipment: _equipment,
      difficulty: _difficulty,
      excluded: widget.excluded,
    );
    final loading = library.isLoading || training.isLoading;
    final failed = library.hasError || training.hasError;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.select ? 'Adicionar exercicio' : 'Biblioteca'),
        actions: [
          IconButton(
            tooltip: 'Atualizar biblioteca',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshing ? null : _refresh,
          ),
          IconButton(
            tooltip: 'Criar exercicio',
            icon: const Icon(Icons.add),
            onPressed: data == null ? null : _create,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _search,
                          decoration: const InputDecoration(
                            labelText: 'Buscar exercicio',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                        ExpansionTile(
                          title: const Text('Filtros'),
                          childrenPadding: const EdgeInsets.only(bottom: 12),
                          children: [
                            _filter(
                              'Grupo muscular',
                              _group,
                              groups,
                              (value) => setState(() => _group = value),
                            ),
                            const SizedBox(height: 12),
                            _filter(
                              'Equipamento',
                              _equipment,
                              equipment,
                              (value) => setState(() => _equipment = value),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<ExerciseDifficulty>(
                              key: ValueKey('difficulty-${_difficulty?.name}'),
                              initialValue: _difficulty,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Dificuldade',
                              ),
                              items: [
                                const DropdownMenuItem<ExerciseDifficulty>(
                                  child: Text('Todas'),
                                ),
                                ...ExerciseDifficulty.values.map(
                                  (value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(value.label),
                                  ),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _difficulty = value),
                            ),
                          ],
                        ),
                        if (_refreshing)
                          const LinearProgressIndicator(
                            semanticsLabel: 'Atualizando biblioteca',
                          ),
                      ],
                    ),
                  ),
                ),
                if (loading || failed || exercises.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : failed
                        ? TrainingError(
                            onRetry: () {
                              ref.invalidate(exerciseCatalogProvider);
                              ref
                                  .read(trainingControllerProvider.notifier)
                                  .reload();
                            },
                          )
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Nenhum exercicio encontrado.'),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: _create,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Criar exercicio'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  )
                else
                  SliverList.builder(
                    itemCount: exercises.length,
                    itemBuilder: (context, index) => _tile(exercises[index]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filter(
    String label,
    String? current,
    List<String> values,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    key: ValueKey('$label-$current'),
    initialValue: current,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem<String>(child: Text('Todos')),
      ...values.map(
        (value) => DropdownMenuItem(value: value, child: Text(value)),
      ),
    ],
    onChanged: onChanged,
  );

  Widget _tile(Exercicio exercise) => ListTile(
    leading: Icon(
      exercise.media == null
          ? Icons.fitness_center
          : Icons.ondemand_video_outlined,
    ),
    title: Text(exercise.name),
    subtitle: Text(
      '${exercise.muscleGroup} · ${exercise.equipmentNames.join(' + ')}'
      '${exercise.id.startsWith('custom-') ? ' · Personalizado' : ''}',
    ),
    trailing: IconButton(
      tooltip: 'Ver execucao de ${exercise.name}',
      icon: const Icon(Icons.play_circle_outline),
      onPressed: () => context.pushNamed(
        'exercise-detail',
        pathParameters: {'id': exercise.id},
      ),
    ),
    onTap: widget.select
        ? () => Navigator.pop(context, exercise)
        : () => context.pushNamed(
            'exercise-detail',
            pathParameters: {'id': exercise.id},
          ),
  );
}
