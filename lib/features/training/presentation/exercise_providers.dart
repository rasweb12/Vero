import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/providers/local_database_provider.dart';
import '../../../shared/utils/result.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/exercise_media_cache.dart';
import '../data/exercise_repository.dart';
import '../domain/training_models.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ExerciseRepository(
    ref.watch(localDatabaseProvider),
    loadBundled: () async {
      final json =
          jsonDecode(
                await rootBundle.loadString('assets/exercises/catalog.json'),
              )
              as Map<String, dynamic>;
      return (json['exercises'] as List).cast<Map<String, dynamic>>();
    },
    loadRemote: client == null
        ? null
        : () async {
            final rows = <Map<String, dynamic>>[];
            for (var page = 0; page < 10; page++) {
              final batch = await client
                  .from('exercises')
                  .select()
                  .order('id')
                  .range(page * 1000, page * 1000 + 999)
                  .timeout(const Duration(seconds: 15));
              rows.addAll(batch);
              if (batch.length < 1000) return rows;
            }
            throw const FormatException('Catalog exceeds supported size.');
          },
  );
});

final exerciseCatalogProvider = FutureProvider<List<Exercicio>>((ref) async {
  final result = await ref.watch(exerciseRepositoryProvider).load();
  return result.fold(
    onFailure: (failure) => throw failure.message,
    onSuccess: (value) => value,
  );
});

final exerciseMediaCacheProvider = Provider<ExerciseMediaCache>(
  (ref) => ExerciseMediaCache(
    directory: () async {
      final root = await getApplicationCacheDirectory();
      return '${root.path}/exercise-media';
    },
  ),
);

Future<Result<void>> refreshExerciseCatalog(WidgetRef ref) async {
  final result = await ref.read(exerciseRepositoryProvider).refresh();
  if (result.isSuccess) ref.invalidate(exerciseCatalogProvider);
  return result;
}
