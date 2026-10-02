import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/database/local_database.dart';
import '../../../shared/utils/result.dart';
import '../../notifications/data/notification_service.dart';
import '../../photos/data/private_photo_store.dart';

class DataPrivacyService {
  const DataPrivacyService({
    required this.database,
    required this.files,
    required this.preferences,
    required this.ownerId,
    required this.client,
    required this.notifications,
  });

  final LocalDatabase database;
  final PrivatePhotoStore files;
  final SharedPreferences preferences;
  final String ownerId;
  final SupabaseClient? client;
  final NotificationService notifications;

  static const _localKeys = [
    'profile',
    'training',
    'measurements',
    'photos',
    'plan',
    'sync:meta',
    'sync:queue',
    'sync:key',
  ];

  Future<Result<Uint8List>> exportData() async {
    try {
      final export = <String, dynamic>{
        'format': 'vero-personal-data-v1',
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'account_id': ownerId,
        'profile': await _readJson('profile:$ownerId'),
        'training': await _readJson('training:$ownerId'),
        'measurements': await _readJson('measurements:$ownerId'),
        'plan': await _readRaw('plan:$ownerId'),
        'photos': await _exportPhotos(),
      };
      return Success(
        Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(export)),
        ),
      );
    } on Exception {
      return const Failure(
        AppFailure(message: 'Nao foi possivel preparar sua exportacao.'),
      );
    }
  }

  Future<Result<void>> deleteEverything() async {
    try {
      final rawPhotos = await _readJson('photos:$ownerId');
      final paths = rawPhotos is List
          ? rawPhotos
                .whereType<Map>()
                .map((photo) => photo['file_name'] as String?)
                .whereType<String>()
                .map((file) => '$ownerId/$file')
                .toList()
          : const <String>[];

      final backend = client;
      if (backend != null) {
        if (paths.isNotEmpty) {
          await backend.storage.from('vero-private').remove(paths);
        }
        await backend.from('sync_records').delete().eq('owner_id', ownerId);
        await backend.from('sync_keys').delete().eq('owner_id', ownerId);
        await backend.from('profiles').delete().eq('id', ownerId);
      }

      for (final suffix in _localKeys) {
        final result = await database.delete('$suffix:$ownerId');
        if (result case Failure<void>(:final failure)) return Failure(failure);
      }
      await files.deleteAll();
      await notifications.cancelAll();
      final prefix = 'notifications:$ownerId:';
      for (final key in preferences.getKeys().where(
        (key) => key.startsWith(prefix),
      )) {
        await preferences.remove(key);
      }
      return const Success(null);
    } on Exception {
      return const Failure(
        AppFailure(
          message:
              'Nao foi possivel apagar tudo. Nenhum dado local foi removido.',
          code: 'data_delete_failed',
        ),
      );
    }
  }

  Future<dynamic> _readJson(String key) async {
    final raw = await _readRaw(key);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  Future<String?> _readRaw(String key) async {
    final result = await database.read(key);
    return result.fold(
      onFailure: (failure) => throw StateError(failure.message),
      onSuccess: (value) => value,
    );
  }

  Future<List<Map<String, dynamic>>> _exportPhotos() async {
    final raw = await _readJson('photos:$ownerId');
    if (raw is! List) return const [];
    final exported = <Map<String, dynamic>>[];
    for (final value in raw.whereType<Map>()) {
      final photo = Map<String, dynamic>.from(value);
      final id = photo['id'] as String?;
      final fileName = photo['file_name'] as String?;
      if (id == null || fileName == null) continue;
      final bytes = await files.read(id, fileName);
      exported.add({...photo, 'image_base64': base64Encode(bytes)});
    }
    return exported;
  }
}
