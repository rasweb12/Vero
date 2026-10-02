import 'package:flutter/material.dart';

import '../domain/exercise_library.dart';
import '../domain/training_models.dart';

class ExerciseLibraryPage extends StatefulWidget {
  const ExerciseLibraryPage({
    this.select = false,
    this.excluded = const {},
    super.key,
  });
  final bool select;
  final Set<String> excluded;
  @override
  State<ExerciseLibraryPage> createState() => _ExerciseLibraryPageState();
}

class _ExerciseLibraryPageState extends State<ExerciseLibraryPage> {
  String _query = '';
  String? _group;
  @override
  Widget build(BuildContext context) {
    final groups = exerciseLibrary
        .map((exercise) => exercise.muscleGroup)
        .toSet()
        .toList();
    final exercises = exerciseLibrary
        .where(
          (exercise) =>
              !widget.excluded.contains(exercise.id) &&
              (_group == null || exercise.muscleGroup == _group) &&
              exercise.name.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.select ? 'Adicionar exercicio' : 'Biblioteca'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Buscar exercicio',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
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
              child: exercises.isEmpty
                  ? const Center(child: Text('Nenhum exercicio encontrado.'))
                  : ListView.builder(
                      itemCount: exercises.length,
                      itemBuilder: (context, index) => _tile(exercises[index]),
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
    subtitle: Text('${exercise.muscleGroup} · ${exercise.type}'),
    trailing: widget.select ? const Icon(Icons.add) : null,
    onTap: widget.select ? () => Navigator.pop(context, exercise) : null,
  );
}
