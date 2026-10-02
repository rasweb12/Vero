import 'package:flutter/material.dart';

import '../../../shared/utils/result.dart';

String formatWeight(double weight) =>
    (weight % 1 == 0 ? weight.toInt().toString() : weight.toStringAsFixed(1))
        .replaceAll('.', ',');
String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

void showTrainingResult(BuildContext context, Result<void> result) {
  if (result case Failure<void>(:final failure)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

class TrainingError extends StatelessWidget {
  const TrainingError({required this.onRetry, super.key});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Nao foi possivel carregar seus treinos. Seus dados foram preservados.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
