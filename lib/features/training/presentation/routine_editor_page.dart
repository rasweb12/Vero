import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/exercise_library.dart';
import '../domain/training_models.dart';
import 'exercise_library_page.dart';
import 'training_controller.dart';
import 'training_widgets.dart';

class RoutineEditorPage extends ConsumerWidget {
  const RoutineEditorPage({this.id, super.key});
  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(trainingControllerProvider)
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, trace) => Scaffold(
          body: TrainingError(
            onRetry: () =>
                ref.read(trainingControllerProvider.notifier).reload(),
          ),
        ),
        data: (data) {
          final routine = data.routines
              .where((value) => value.id == id)
              .firstOrNull;
          if (id != null && routine == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Rotina nao encontrada.')),
            );
          }
          return _RoutineEditor(key: ValueKey(id ?? 'new'), routine: routine);
        },
      );
}

class _RoutineEditor extends ConsumerStatefulWidget {
  const _RoutineEditor({this.routine, super.key});
  final Treino? routine;
  @override
  ConsumerState<_RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends ConsumerState<_RoutineEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late List<ExercicioTreino> _exercises;
  late int _rest;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.routine?.name ?? '');
    _exercises = [...?widget.routine?.exercises];
    _rest = widget.routine?.restSeconds ?? 60;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final result = await ref
        .read(trainingControllerProvider.notifier)
        .saveRoutine(
          Treino(
            id: widget.routine?.id ?? newTrainingId(),
            name: _name.text.trim(),
            exercises: _exercises,
            restSeconds: _rest,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    showTrainingResult(context, result);
    if (result.isSuccess) {
      _dirty = false;
      context.goNamed('training');
    }
  }

  Future<void> _addExercise() async {
    final exercise = await Navigator.of(context).push<Exercicio>(
      MaterialPageRoute(
        builder: (_) => ExerciseLibraryPage(
          select: true,
          excluded: _exercises.map((value) => value.exerciseId).toSet(),
        ),
      ),
    );
    if (exercise == null || !mounted) return;
    setState(() {
      _dirty = true;
      _exercises.add(
        ExercicioTreino(
          exerciseId: exercise.id,
          sets: const [Serie(), Serie(), Serie()],
        ),
      );
    });
  }

  void _update(int exerciseIndex, int setIndex, {int? reps, double? weight}) {
    final exercise = _exercises[exerciseIndex];
    final sets = [...exercise.sets];
    sets[setIndex] = sets[setIndex].copyWith(reps: reps, weight: weight);
    _exercises[exerciseIndex] = exercise.withSets(sets);
    _dirty = true;
  }

  @override
  Widget build(BuildContext context) {
    final customExercises =
        ref.watch(trainingControllerProvider).asData?.value.customExercises ??
        const <Exercicio>[];
    return PopScope(
      canPop: !_saving && !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _saving) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Descartar alteracoes?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continuar editando'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          setState(() => _dirty = false);
          context.goNamed('training');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.routine == null ? 'Novo treino' : 'Editar treino'),
          actions: [
            IconButton(
              tooltip: 'Salvar treino',
              icon: const Icon(Icons.save_outlined),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _form,
            onChanged: () {
              if (!_dirty) setState(() => _dirty = true);
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: 'Nome do treino',
                  ),
                  validator: (value) =>
                      value == null ||
                          value.trim().isEmpty ||
                          value.trim().length > 80
                      ? 'Use um nome de ate 80 caracteres.'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _rest,
                  decoration: const InputDecoration(
                    labelText: 'Repouso entre series',
                  ),
                  items:
                      [
                            0,
                            30,
                            45,
                            60,
                            90,
                            120,
                            180,
                            300,
                            if (![
                              0,
                              30,
                              45,
                              60,
                              90,
                              120,
                              180,
                              300,
                            ].contains(_rest))
                              _rest,
                          ]
                          .map(
                            (seconds) => DropdownMenuItem(
                              value: seconds,
                              child: Text(
                                seconds == 0
                                    ? 'Sem contador'
                                    : '$seconds segundos',
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _rest = value ?? 60;
                          _dirty = true;
                        }),
                ),
                const SizedBox(height: 24),
                for (final (exerciseIndex, exercise) in _exercises.indexed) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          exerciseById(
                            exercise.exerciseId,
                            customExercises: customExercises,
                          ).name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remover exercicio',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                _exercises.removeAt(exerciseIndex);
                                _dirty = true;
                              }),
                      ),
                    ],
                  ),
                  for (final (setIndex, set) in exercise.sets.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(width: 28, child: Text('${setIndex + 1}')),
                          Expanded(
                            child: TextFormField(
                              key: ValueKey(
                                '${exercise.exerciseId}-$setIndex-reps',
                              ),
                              initialValue: '${set.reps}',
                              enabled: !_saving,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Reps',
                              ),
                              validator: (value) {
                                final parsed = int.tryParse(value ?? '');
                                return parsed == null ||
                                        parsed < 1 ||
                                        parsed > 999
                                    ? '1 a 999'
                                    : null;
                              },
                              onChanged: (value) => _update(
                                exerciseIndex,
                                setIndex,
                                reps: int.tryParse(value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              key: ValueKey(
                                '${exercise.exerciseId}-$setIndex-weight',
                              ),
                              initialValue: formatWeight(set.weight),
                              enabled: !_saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Kg',
                              ),
                              validator: (value) {
                                final parsed = double.tryParse(
                                  (value ?? '').replaceAll(',', '.'),
                                );
                                return parsed == null ||
                                        !parsed.isFinite ||
                                        parsed < 0 ||
                                        parsed > 1000
                                    ? '0 a 1000'
                                    : null;
                              },
                              onChanged: (value) => _update(
                                exerciseIndex,
                                setIndex,
                                weight: double.tryParse(
                                  value.replaceAll(',', '.'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Remover ultima serie',
                        icon: const Icon(Icons.remove),
                        onPressed: _saving || exercise.sets.length <= 1
                            ? null
                            : () => setState(() {
                                final current = _exercises[exerciseIndex];
                                _exercises[exerciseIndex] = current.withSets(
                                  current.sets.sublist(
                                    0,
                                    current.sets.length - 1,
                                  ),
                                );
                                _dirty = true;
                              }),
                      ),
                      Text('${exercise.sets.length} series'),
                      IconButton(
                        tooltip: 'Adicionar serie',
                        icon: const Icon(Icons.add),
                        onPressed: _saving || exercise.sets.length >= 20
                            ? null
                            : () => setState(() {
                                final current = _exercises[exerciseIndex];
                                _exercises[exerciseIndex] = current.withSets([
                                  ...current.sets,
                                  current.sets.last,
                                ]);
                                _dirty = true;
                              }),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                ],
                OutlinedButton.icon(
                  onPressed: _saving ? null : _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar exercicio'),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Salvando...' : 'Salvar treino'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
