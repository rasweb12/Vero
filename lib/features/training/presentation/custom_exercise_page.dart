import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/result.dart';
import '../domain/exercise_library.dart';
import '../domain/training_models.dart';
import 'training_controller.dart';

class CustomExercisePage extends ConsumerStatefulWidget {
  const CustomExercisePage({
    this.initialMuscleGroup,
    this.initialName = '',
    super.key,
  });

  final String? initialMuscleGroup;
  final String initialName;

  @override
  ConsumerState<CustomExercisePage> createState() => _CustomExercisePageState();
}

class _CustomExercisePageState extends ConsumerState<CustomExercisePage> {
  final _form = GlobalKey<FormState>();
  final _id = 'custom-${newTrainingId()}';
  late final TextEditingController _name;
  String? _group;
  String? _equipment;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _group = widget.initialMuscleGroup;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final exercise = Exercicio(
      id: _id,
      name: _name.text.trim(),
      muscleGroup: _group!,
      type: _equipment!,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(trainingControllerProvider.notifier)
        .saveCustomExercise(exercise);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result case Failure<void>(:final failure)) {
      setState(() => _error = failure.message);
      return;
    }
    Navigator.of(context).pop(exercise);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Novo exercicio')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !_saving,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nome do exercicio',
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Informe o nome do exercicio.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('custom-muscle-group'),
                    initialValue: _group,
                    decoration: const InputDecoration(
                      labelText: 'Grupo muscular',
                    ),
                    items: exerciseMuscleGroups
                        .map(
                          (group) => DropdownMenuItem(
                            value: group,
                            child: Text(group),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'Selecione o grupo muscular.' : null,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _group = value),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('custom-equipment'),
                    initialValue: _equipment,
                    decoration: const InputDecoration(labelText: 'Equipamento'),
                    items: exerciseEquipmentTypes
                        .map(
                          (equipment) => DropdownMenuItem(
                            value: equipment,
                            child: Text(equipment),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        value == null ? 'Selecione o equipamento.' : null,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _equipment = value),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Salvando...' : 'Salvar exercicio'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
