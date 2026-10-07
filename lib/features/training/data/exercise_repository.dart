import 'dart:convert';

import '../../../shared/database/local_database.dart';
import '../../../shared/utils/result.dart';
import '../domain/exercise_library.dart';
import '../domain/training_models.dart';

typedef CatalogLoader = Future<List<Map<String, dynamic>>> Function();

class ExerciseRepository {
  const ExerciseRepository(
    this.database, {
    required this.loadBundled,
    this.loadRemote,
  });
  final LocalDatabase database;
  final CatalogLoader loadBundled;
  final CatalogLoader? loadRemote;
  static const cacheKey = 'exercise-catalog:v1';

  // Bundled metadata is always available; reading never depends on the network.
  Future<Result<List<Exercicio>>> load() async {
    try {
      final catalog = {
        for (final exercise in exerciseLibrary) exercise.id: exercise,
      };
      for (final row in await loadBundled()) {
        final exercise = Exercicio.fromJson(row);
        catalog[exercise.id] = exercise;
      }
      final cached = await database.read(cacheKey);
      if (cached case Success<String?>(:final value) when value != null) {
        try {
          final snapshot = jsonDecode(value) as Map<String, dynamic>;
          if (snapshot['version'] == 1) {
            final rows = _parse(snapshot['exercises'] as List);
            for (final exercise in rows) {
              catalog[exercise.id] = exercise;
            }
          }
        } on Object {
          // Keep a damaged cache for diagnostics and fall back to bundled data.
        }
      }
      return Success(List.unmodifiable(catalog.values));
    } on Object {
      return const Failure(
        AppFailure(message: 'Nao foi possivel abrir a biblioteca.'),
      );
    }
  }

  Future<Result<void>> refresh() async {
    if (loadRemote == null) {
      return const Failure(
        AppFailure(
          message:
              'A biblioteca local esta disponivel. Tente atualizar mais tarde.',
        ),
      );
    }
    try {
      final exercises = _parse(await loadRemote!());
      return database.write(
        cacheKey,
        jsonEncode({
          'version': 1,
          'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
        }),
      );
    } on Object {
      return const Failure(
        AppFailure(
          message:
              'Nao foi possivel atualizar. Sua biblioteca continua disponivel offline.',
        ),
      );
    }
  }

  List<Exercicio> _parse(List<dynamic> rows) {
    final exercises = rows
        .map((row) => Exercicio.fromJson(row as Map<String, dynamic>))
        .toList();
    if (exercises.length > 10000 ||
        exercises.map((exercise) => exercise.id).toSet().length !=
            exercises.length ||
        exercises.any(
          (exercise) =>
              exercise.id.startsWith('custom-') ||
              !RegExp(r'^[a-z0-9][a-z0-9-]{0,99}$').hasMatch(exercise.id) ||
              exercise.name.trim().isEmpty,
        )) {
      throw const FormatException('Invalid catalog.');
    }
    return exercises;
  }
}
