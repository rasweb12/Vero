import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class IsarEncryptionKeyStore {
  const IsarEncryptionKeyStore({
    this.storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(storageNamespace: 'vero_secure_storage'),
    ),
  });

  static const _storageKey = 'vero_isar_encryption_key_v1';
  static const _keyLength = 64;
  static const _keyAlphabet =
      '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_';

  final FlutterSecureStorage storage;

  Future<String> readOrCreateKey() async {
    final storedKey = await storage.read(key: _storageKey);

    if (storedKey != null) {
      // Never replace an invalid key: existing records would become unreadable.
      if (storedKey.length != _keyLength ||
          storedKey
              .split('')
              .any((character) => !_keyAlphabet.contains(character))) {
        throw StateError('Invalid database key in secure storage.');
      }
      return storedKey;
    }

    final newKey = _generateKey();
    await storage.write(key: _storageKey, value: newKey);

    return newKey;
  }

  String _generateKey() {
    final random = Random.secure();
    final buffer = StringBuffer();

    for (var index = 0; index < _keyLength; index++) {
      buffer.write(_keyAlphabet[random.nextInt(_keyAlphabet.length)]);
    }

    return buffer.toString();
  }
}
