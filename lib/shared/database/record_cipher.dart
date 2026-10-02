import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Encrypts values and authenticates their storage key to prevent record swaps.
class RecordCipher {
  RecordCipher._(this._key);

  final SecretKey _key;
  final AesGcm _algorithm = AesGcm.with256bits();

  Future<Uint8List> encryptBytes(
    List<int> bytes, {
    required String recordKey,
  }) async {
    final box = await _algorithm.encrypt(
      bytes,
      secretKey: _key,
      aad: utf8.encode(recordKey),
    );
    return Uint8List.fromList([1, ...box.concatenation()]);
  }

  Future<Uint8List> decryptBytes(
    List<int> bytes, {
    required String recordKey,
  }) async {
    if (bytes.isEmpty || bytes.first != 1) {
      throw const FormatException('Unsupported photo version.');
    }
    final box = SecretBox.fromConcatenation(
      bytes.sublist(1),
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    return Uint8List.fromList(
      await _algorithm.decrypt(
        box,
        secretKey: _key,
        aad: utf8.encode(recordKey),
      ),
    );
  }

  static Future<RecordCipher> fromStorageKey(String storageKey) async {
    final digest = await Sha256().hash(utf8.encode(storageKey));
    return RecordCipher._(SecretKey(digest.bytes));
  }

  Future<String> encrypt(String value, {required String recordKey}) async {
    final box = await _algorithm.encrypt(
      utf8.encode(value),
      secretKey: _key,
      aad: utf8.encode(recordKey),
    );
    return 'v1:${base64Encode(box.concatenation())}';
  }

  Future<String> decrypt(String value, {required String recordKey}) async {
    if (!value.startsWith('v1:')) {
      throw const FormatException('Unsupported encrypted record version.');
    }
    final box = SecretBox.fromConcatenation(
      base64Decode(value.substring(3)),
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    final bytes = await _algorithm.decrypt(
      box,
      secretKey: _key,
      aad: utf8.encode(recordKey),
    );
    return utf8.decode(bytes);
  }
}
