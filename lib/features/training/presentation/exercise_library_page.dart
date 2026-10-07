import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exercise_library.dart';
import '../domain/training_models.dart';
import 'custom_exercise_page.dart';
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
  String _query = '';
  String? _group;

  @override
  void dispose() {
    _search.dispose();
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final training = ref.watch(trainingControllerProvider);
    final data = training.asData?.value;
    final catalog = [...exerciseLibrary, ...?data?.customExercises];
    final groups = catalog
        .map((exercise) => exercise.muscleGroup)
        .toSet()
        .toList();
    final exercises = catalog
        .where(
          (exercise) =>
              !widget.excluded.contains(exercise.id) &&
              (_group == null || exercise.muscleGroup == _group) &&
              exerciseMatchesQuery(exercise, _query),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.select ? 'Adicionar exercicio' : 'Biblioteca'),
        actions: [
          IconButton(
            tooltip: 'Criar exercicio',
            icon: const Icon(Icons.add),
            onPressed: data == null ? null : _create,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_group ?? 'Todos'),
                    initialValue: _group ?? 'Todos',
                    decoration: const InputDecoration(
                      labelText: 'Grupo muscular',
                    ),
                    items: ['Todos', ...groups]
                        .map(
                          (group) => DropdownMenuItem(
                            value: group,
                            child: Text(group),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(
                      () => _group = value == 'Todos' ? null : value,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: training.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, trace) => TrainingError(
                  onRetry: () =>
                      ref.read(trainingControllerProvider.notifier).reload(),
                ),
                data: (_) => exercises.isEmpty
                    ? Center(
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
                      )
                    : ListView.builder(
                        itemCount: exercises.length,
                        itemBuilder: (context, index) =>
                            _tile(exercises[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Exercicio exercise) => ListTile(
    leading: const Icon(Icons.fitness_center),
    title: Text(exercise.name),
    subtitle: Text(
      '${exercise.muscleGroup} · ${exercise.type}'
      '${exercise.id.startsWith('custom-') ? ' · Personalizado' : ''}',
    ),
    trailing: widget.select ? const Icon(Icons.add) : null,
    onTap: widget.select ? () => Navigator.pop(context, exercise) : null,
  );
}
