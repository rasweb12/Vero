import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:vero/shared/database/local_database.dart';
import 'package:vero/shared/database/record_cipher.dart';
import 'package:vero/shared/models/local_app_metadata.dart';
import 'package:vero/shared/utils/result.dart';

void main() {
  test(
    'encrypted values survive closing, reopening and replacement',
    () async {
      // Use the native library already supplied by the resolved Flutter plugin.
      final configFile = File('.dart_tool/package_config.json').absolute;
      final config =
          jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      final packages = (config['packages'] as List)
          .cast<Map<String, dynamic>>();
      final plugin = packages.singleWhere(
        (entry) => entry['name'] == 'isar_flutter_libs',
      );
      final rootUri = plugin['rootUri'] as String;
      final pluginRoot = configFile.uri.resolve(
        rootUri.endsWith('/') ? rootUri : '$rootUri/',
      );
      await Isar.initializeIsarCore(
        libraries: {
          Abi.windowsX64: pluginRoot.resolve('windows/isar.dll').toFilePath(),
        },
      );
      final directory = await Directory.systemTemp.createTemp(
        'vero_database_test_',
      );
      Isar? instance;
      addTearDown(() async {
        if (instance?.isOpen ?? false) await instance!.close();
        await directory.delete(recursive: true);
      });
      Future<Isar> open() => Isar.open(
        [LocalAppMetadataSchema],
        directory: directory.path,
        name: 'encrypted_test',
        inspector: false,
      );
      instance = await open();
      final cipher = await RecordCipher.fromStorageKey('integration-test-key');
      final database = LocalDatabase(instance, cipher);
      expect(
        (await database.write('opaque-1', 'private-value')).isSuccess,
        isTrue,
      );
      final raw = await instance.localAppMetadatas.getByKey('opaque-1');
      expect(raw!.value, startsWith('v1:'));
      expect(raw.value, isNot(contains('private-value')));
      await database.close();
      instance = await open();
      final reopened = LocalDatabase(instance, cipher);
      expect(
        (await reopened.read('opaque-1') as Success<String?>).value,
        'private-value',
      );
      expect(
        (await reopened.write('opaque-1', 'updated-value')).isSuccess,
        isTrue,
      );
      expect(await instance.localAppMetadatas.count(), 1);
      expect(
        (await reopened.read('opaque-1') as Success<String?>).value,
        'updated-value',
      );
      expect(
        (await reopened.read('missing') as Success<String?>).value,
        isNull,
      );
      final wrongKey = LocalDatabase(
        instance,
        await RecordCipher.fromStorageKey('wrong-key'),
      );
      expect((await wrongKey.read('opaque-1')).isFailure, isTrue);
    },
    skip: !Platform.isWindows,
  );
}
