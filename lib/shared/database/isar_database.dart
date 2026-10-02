import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/local_app_metadata.dart';
import 'isar_encryption_key_store.dart';
import 'local_database.dart';
import 'record_cipher.dart';

class IsarDatabase {
  const IsarDatabase._();

  static const instanceName = 'vero';

  static Future<LocalDatabase> open({
    IsarEncryptionKeyStore keyStore = const IsarEncryptionKeyStore(),
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Secure local storage requires a native device.');
    }
    final key = await keyStore.readOrCreateKey();
    final cipher = await RecordCipher.fromStorageKey(key);
    final directory = await getApplicationSupportDirectory();
    final isar =
        Isar.getInstance(instanceName) ??
        await Isar.open(
          [LocalAppMetadataSchema],
          directory: directory.path,
          name: instanceName,
          inspector: false,
        );

    return LocalDatabase(isar, cipher);
  }
}
