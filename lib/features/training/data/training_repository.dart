import 'dart:convert';

import '../../../shared/database/local_database.dart';
import '../../../shared/utils/result.dart';
import '../domain/training_models.dart';

class TrainingRepository {
  const TrainingRepository(this.database, this.ownerId);
  final LocalDatabase database;
  final String ownerId;

  Future<Result<TrainingData>> load() async {
    final stored = await database.read('training:$ownerId');
    return stored.fold(
      onFailure: (failure) => Failure(failure),
      onSuccess: (value) {
        if (value == null) return Success(TrainingData());
        try {
          return Success(
            TrainingData.fromJson(jsonDecode(value) as Map<String, dynamic>),
          );
        } on Object {
          return const Failure(
            AppFailure(
              message:
                  'Nao foi possivel ler seus treinos. Os dados foram preservados.',
            ),
          );
        }
      },
    );
  }

  Future<Result<void>> save(TrainingData value) =>
      database.write('training:$ownerId', jsonEncode(value.toJson()));
}
