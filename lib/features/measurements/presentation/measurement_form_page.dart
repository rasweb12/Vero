import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/record_id.dart';
import '../../../shared/widgets/load_failure.dart';
import '../../subscription/presentation/plan_provider.dart';
import '../../training/presentation/training_widgets.dart';
import '../domain/measurement_models.dart';
import 'measurement_controller.dart';

class MeasurementFormPage extends ConsumerStatefulWidget {
  const MeasurementFormPage({super.key});
  @override
  ConsumerState<MeasurementFormPage> createState() =>
      _MeasurementFormPageState();
}

class _MeasurementFormPageState extends ConsumerState<MeasurementFormPage> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final metric in BodyMetric.values) metric: TextEditingController(),
  };
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save(List<BodyMetric> metrics) async {
    if (_saving || !_form.currentState!.validate()) return;
    final values = <BodyMetric, double>{};
    for (final metric in metrics) {
      final value = double.tryParse(
        _fields[metric]!.text.trim().replaceAll(',', '.'),
      );
      if (value != null) values[metric] = value;
    }
    setState(() => _saving = true);
    final result = await ref
        .read(measurementControllerProvider.notifier)
        .saveRecord(
          RegistroMedida(
            id: newRecordId(),
            date: _date,
            weight: values.remove(BodyMetric.weight),
            circumferences: values,
            notes: _notes.text.trim(),
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    showTrainingResult(context, result);
    if (result.isSuccess) context.goNamed('measurements');
  }

  @override
  Widget build(BuildContext context) {
    final limit = ref.watch(effectivePlanProvider).measurementLimit;
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar medidas')),
      body: ref
          .watch(measurementControllerProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, trace) => LoadFailure(
              onRetry: () =>
                  ref.read(measurementControllerProvider.notifier).reload(),
            ),
            data: (data) => Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(formatDate(_date)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _saving
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                            );
                            if (date != null && mounted) {
                              setState(() => _date = date);
                            }
                          },
                  ),
                  for (final metric in data.allowedMetrics(limit))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextFormField(
                        controller: _fields[metric],
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: metric.label,
                          suffixText: metric.unit,
                        ),
                        validator: (text) {
                          if (text == null || text.trim().isEmpty) return null;
                          final value = double.tryParse(
                            text.trim().replaceAll(',', '.'),
                          );
                          return value == null || !metric.accepts(value)
                              ? 'Use ${metric.minimum.toInt()} a ${metric.maximum.toInt()} ${metric.unit}.'
                              : null;
                        },
                      ),
                    ),
                  TextFormField(
                    controller: _notes,
                    enabled: !_saving,
                    maxLength: 1000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _save(data.allowedMetrics(limit)),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Salvando...' : 'Salvar registro'),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
