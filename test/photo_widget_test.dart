import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vero/features/photos/data/photo_repository.dart';
import 'package:vero/features/photos/data/private_photo_store.dart';
import 'package:vero/features/photos/presentation/photo_controller.dart';
import 'package:vero/features/photos/presentation/photos_page.dart';
import 'package:vero/features/subscription/domain/app_plan.dart';
import 'package:vero/features/subscription/presentation/plan_provider.dart';
import 'package:vero/shared/database/record_cipher.dart';
import 'package:vero/shared/theme/app_theme.dart';
import 'package:vero/shared/utils/result.dart';

import 'profile_plan_test.dart' show MemoryDatabase;

class MemoryPhotoStore extends PrivatePhotoStore {
  MemoryPhotoStore(RecordCipher cipher)
    : super(Directory.systemTemp, cipher, 'test');
  final values = <String, Uint8List>{};
  @override
  Future<String> save(String id, Uint8List bytes) async {
    values[id] = bytes;
    return id;
  }

  @override
  Future<Uint8List> read(String id, String fileName) async => values[id]!;
  @override
  Future<void> delete(String fileName) async {
    values.remove(fileName);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PhotoRepository repository;
  setUp(() async {
    final store = MemoryPhotoStore(
      await RecordCipher.fromStorageKey('test-only'),
    );
    repository = PhotoRepository(MemoryDatabase(), store, 'test');
    for (var index = 0; index < 2; index++) {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawColor(
        index == 0 ? const Color(0xFF0D9488) : const Color(0xFF3B82F6),
        ui.BlendMode.src,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(80, 120);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await repository.add(
        data!.buffer.asUint8List(),
        DateTime(2026, 9, 10 + index),
        AppPlan.free,
      );
      image.dispose();
      picture.dispose();
    }
  });

  testWidgets('gallery selection compares two images and delete removes one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoRepositoryProvider.overrideWith((ref) async => repository),
          planProvider.overrideWith((ref) async => const Success(AppPlan.free)),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const PhotosPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(2));
    await tester.tap(find.byType(Checkbox).first);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Comparar fotos selecionadas'));
    await tester.pumpAndSettle();
    expect(find.text('Antes e depois'), findsOneWidget);
    expect(find.text('Antes · 10/09/2026'), findsOneWidget);
    expect(find.text('Depois · 11/09/2026'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Excluir foto de 11/09/2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('1/5 fotos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
