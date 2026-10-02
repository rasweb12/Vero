import 'dart:convert';

import '../../../shared/database/local_database.dart';
import '../../../shared/utils/result.dart';
import '../domain/measurement_models.dart';

class MeasurementRepository {
  const MeasurementRepository(this.database, this.ownerId);
  final LocalDatabase database;
  final String ownerId;
  Future<Result<MeasurementData>> load() async {
    final result = await database.read('measurements:$ownerId');
    return result.fold(
      onFailure: (failure) => Failure(failure),
      onSuccess: (value) {
        if (value == null) return Success(MeasurementData());
        try {
          return Success(
            MeasurementData.fromJson(jsonDecode(value) as Map<String, dynamic>),
          );
        } on Object {
          return const Failure(
            AppFailure(
              message:
                  'Nao foi possivel ler suas medidas. Os registros foram preservados.',
            ),
          );
        }
      },
    );
  }

  Future<Result<void>> save(MeasurementData data) =>
      database.write('measurements:$ownerId', jsonEncode(data.toJson()));
}
