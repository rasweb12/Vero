import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vero/features/photos/data/photo_repository.dart';
import 'package:vero/features/photos/data/private_photo_store.dart';
import 'package:vero/features/photos/domain/progress_photo.dart';
import 'package:vero/features/photos/presentation/photo_controller.dart';
import 'package:vero/features/subscription/domain/app_plan.dart';
import 'package:vero/shared/database/record_cipher.dart';
import 'package:vero/shared/utils/result.dart';

import 'profile_plan_test.dart' show MemoryDatabase;

class WriteFailDatabase extends MemoryDatabase {
  @override
  Future<Result<void>> write(String key, String value) async =>
      const Failure(AppFailure(message: 'Disk full'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late MemoryDatabase database;
  late PrivatePhotoStore files;
  late PhotoRepository repository;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('vero_photo_test_');
    database = MemoryDatabase();
    files = PrivatePhotoStore(
      temporary,
      await RecordCipher.fromStorageKey('test-only'),
      'a',
    );
    repository = PhotoRepository(database, files, 'a');
  });
  tearDown(() async => temporary.delete(recursive: true));

  test(
    'encrypted contents and names roundtrip; record swaps and path traversal fail',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final name = await files.save('opaque-id', bytes);
      expect(name, isNot(contains('opaque-id')));
      final stored = await temporary
          .list(recursive: true)
          .where((entry) => entry is File)
          .cast<File>()
          .first;
      expect(await stored.readAsBytes(), isNot(orderedEquals(bytes)));
      expect(await files.read('opaque-id', name), bytes);
      await expectLater(files.read('other-id', name), throwsA(anything));
      await expectLater(
        files.read('opaque-id', '../outside.ver o'),
        throwsFormatException,
      );
      final altered = await stored.readAsBytes();
      altered[altered.length - 1] ^= 1;
      await stored.writeAsBytes(altered);
      await expectLater(files.read('opaque-id', name), throwsA(anything));
    },
  );
  test(
    'free rejects sixth photo, premium permits it; metadata is account-scoped',
    () async {
      for (var i = 0; i < 5; i++) {
        expect(
          (await repository.add(
            Uint8List.fromList([i]),
            DateTime.now(),
            AppPlan.free,
          )).isSuccess,
          isTrue,
        );
      }
      expect(
        (await repository.add(
          Uint8List(1),
          DateTime.now(),
          AppPlan.free,
        )).isFailure,
        isTrue,
      );
      expect(
        (await repository.add(
          Uint8List(1),
          DateTime.now(),
          AppPlan.annual,
        )).isSuccess,
        isTrue,
      );
      final rows =
          (await repository.load() as Success<List<ProgressPhoto>>).value;
      expect(rows.length, 6);
      final other = PhotoRepository(database, files, 'b');
      expect(
        (await other.load() as Success<List<ProgressPhoto>>).value,
        isEmpty,
      );
      await expectLater(other.read(rows.first.id), throwsStateError);
    },
  );
  test('failed manifest write cleans new encrypted file', () async {
    final failing = PhotoRepository(WriteFailDatabase(), files, 'a');
    expect(
      (await failing.add(
        Uint8List(10),
        DateTime.now(),
        AppPlan.free,
      )).isFailure,
      isTrue,
    );
    expect(
      await temporary
          .list(recursive: true)
          .where((entry) => entry is File)
          .length,
      0,
    );
  });
  test(
    'delete removes manifest and private file, pending picker respects owner',
    () async {
      await repository.add(Uint8List(10), DateTime.now(), AppPlan.free);
      final photo = (await repository.load() as Success<List<ProgressPhoto>>)
          .value
          .single;
      await repository.remove(photo.id);
      expect(
        (await repository.load() as Success<List<ProgressPhoto>>).value,
        isEmpty,
      );
      expect(
        await temporary
            .list(recursive: true)
            .where((entry) => entry is File)
            .length,
        0,
      );
      final date = DateTime(2026, 9, 20);
      await repository.markPending(date);
      expect(await repository.pendingDate(), date);
      expect(await PhotoRepository(database, files, 'b').pendingDate(), isNull);
    },
  );
  test(
    'parallel imports are serialized and cannot exceed free limit',
    () async {
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawColor(const ui.Color(0xFF0D9488), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(8, 8);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
      final controller = PhotoController(
        Future.value(repository),
        () => AppPlan.free,
      );
      await controller.ready;
      final results = await Future.wait(
        List.generate(
          6,
          (_) => controller.importPhoto(
            XFile.fromData(bytes, name: 'private.png'),
            DateTime.now(),
          ),
        ),
      );
      expect(results.where((result) => result.isSuccess).length, 5);
      expect(controller.state.requireValue.length, 5);
      controller.dispose();
    },
  );
}
