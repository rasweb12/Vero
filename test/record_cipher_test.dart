import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vero/shared/database/record_cipher.dart';

void main() {
  late RecordCipher cipher;

  setUp(() async {
    cipher = await RecordCipher.fromStorageKey('test-key-only');
  });

  test('round trip and unique nonce per write', () async {
    const value = '{"weight":72.5}';
    final first = await cipher.encrypt(value, recordKey: 'record-1');
    final second = await cipher.encrypt(value, recordKey: 'record-1');
    expect(first, isNot(second));
    expect(first, isNot(contains(value)));
    final reopened = await RecordCipher.fromStorageKey('test-key-only');
    expect(await reopened.decrypt(first, recordKey: 'record-1'), value);
  });

  test('rejects tampered ciphertext, wrong key and record swaps', () async {
    final encrypted = await cipher.encrypt('private', recordKey: 'record-1');
    final bytes = base64Decode(encrypted.substring(3));
    bytes[12] ^= 1;
    final wrongCipher = await RecordCipher.fromStorageKey('another-key');
    await expectLater(
      cipher.decrypt('v1:${base64Encode(bytes)}', recordKey: 'record-1'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    await expectLater(
      wrongCipher.decrypt(encrypted, recordKey: 'record-1'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    await expectLater(
      cipher.decrypt(encrypted, recordKey: 'record-2'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('rejects plaintext and unknown versions', () async {
    for (final value in ['plaintext', 'v2:AAAA', 'v1:!']) {
      await expectLater(
        cipher.decrypt(value, recordKey: 'record-1'),
        throwsFormatException,
      );
    }
  });
}
