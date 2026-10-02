import 'package:isar/isar.dart';

import '../models/local_app_metadata.dart';
import '../utils/result.dart';
import 'record_cipher.dart';

/// Values are encrypted; keys must be opaque identifiers, never personal data.
class LocalDatabase {
  const LocalDatabase(this._isar, this._cipher);

  final Isar _isar;
  final RecordCipher _cipher;

  Future<Result<void>> write(String key, String value) async {
    try {
      final encryptedValue = await _cipher.encrypt(value, recordKey: key);
      final record = LocalAppMetadata()
        ..key = key
        ..value = encryptedValue;
      await _isar.writeTxn(() async {
        await _isar.localAppMetadatas.put(record);
      });
      return const Success(null);
    } on Exception {
      return const Failure(
        AppFailure(
          message: 'Nao foi possivel salvar os dados no dispositivo.',
          code: 'local_write_failed',
        ),
      );
    }
  }

  Future<Result<String?>> read(String key) async {
    try {
      final record = await _isar.localAppMetadatas.getByKey(key);
      if (record == null) return const Success(null);
      return Success(await _cipher.decrypt(record.value, recordKey: key));
    } on Exception {
      return const Failure(
        AppFailure(
          message: 'Nao foi possivel ler os dados protegidos.',
          code: 'local_read_failed',
        ),
      );
    }
  }

  Future<Result<void>> delete(String key) async {
    try {
      await _isar.writeTxn(() async {
        await _isar.localAppMetadatas.deleteByKey(key);
      });
      return const Success(null);
    } on Exception {
      return const Failure(
        AppFailure(
          message: 'Nao foi possivel apagar os dados do dispositivo.',
          code: 'local_delete_failed',
        ),
      );
    }
  }

  Future<void> close() async {
    await _isar.close();
  }
}
