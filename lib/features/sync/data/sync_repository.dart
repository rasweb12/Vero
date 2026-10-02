import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/database/local_database.dart';
import '../../../shared/database/record_cipher.dart';
import '../../../shared/utils/result.dart';
import '../../photos/data/private_photo_store.dart';
import '../domain/sync_models.dart';

class SyncRepository {
  const SyncRepository({
    required this.database,
    required this.client,
    required this.files,
    required this.ownerId,
  });

  static const _queueVersion = 1;
  static const _recordTypes = <String>[
    'profile',
    'training',
    'measurements',
    'photos',
  ];

  final LocalDatabase database;
  final SupabaseClient? client;
  final PrivatePhotoStore files;
  final String ownerId;

  String get _metaKey => 'sync:meta:$ownerId';
  String get _queueKey => 'sync:queue:$ownerId';
  String get _syncKey => 'sync:key:$ownerId';

  Future<Result<int>> pendingCount() async {
    final queue = await _refreshQueue();
    return queue.fold(
      onFailure: (failure) => Failure(failure),
      onSuccess: (items) => Success(items.length),
    );
  }

  Future<Result<SyncSummary>> sync() async {
    final queueResult = await _refreshQueue();
    if (queueResult case Failure<List<_QueueItem>>(:final failure)) {
      return Failure(failure);
    }
    final queue = (queueResult as Success<List<_QueueItem>>).value;
    var pending = queue.length;
    final backend = client;
    if (backend == null) {
      return Success(SyncSummary(pending: pending, syncedAt: DateTime.now()));
    }

    try {
      final syncCipher = await _readSyncCipher(backend);
      for (final type in _recordTypes) {
        final raw = await _readLocal(type);
        if (raw == null) continue;
        final hash = await _hash(raw);
        final meta = await _readMeta();
        final previous = meta[type] as Map<String, dynamic>?;
        final localChanged = previous?['local_hash'] != hash;
        final localChangedAt = DateTime.tryParse(
          previous?['local_changed_at'] as String? ?? '',
        );
        final remote = await backend
            .from('sync_records')
            .select('payload,updated_at')
            .eq('owner_id', ownerId)
            .eq('record_type', type)
            .maybeSingle();

        final remoteUpdated = DateTime.tryParse(
          remote?['updated_at'] as String? ?? '',
        );
        final remoteDate = remoteUpdated;
        final remoteRow = remote;
        final useRemote = !localChanged && remoteDate != null;
        final remoteIsNewer =
            remoteDate != null &&
            localChangedAt != null &&
            remoteDate.isAfter(localChangedAt);

        if (remoteRow != null && (useRemote || remoteIsNewer)) {
          final payload = Map<String, dynamic>.from(
            remoteRow['payload'] as Map,
          );
          final decoded = payload['data'];
          if (decoded is! Map && decoded is! List) {
            throw const FormatException('Invalid remote sync payload.');
          }
          final saved = await _writeLocal(type, jsonEncode(decoded));
          if (saved case Failure<void>(:final failure)) {
            return Failure(failure);
          }
          final newHash = await _hash(jsonEncode(decoded));
          meta[type] = {
            'local_hash': newHash,
            'synced_hash': newHash,
            'local_changed_at': remoteDate.toUtc().toIso8601String(),
            'remote_updated_at': remoteDate.toUtc().toIso8601String(),
          };
        } else {
          final updatedAt = localChangedAt ?? DateTime.now().toUtc();
          await backend.from('sync_records').upsert({
            'owner_id': ownerId,
            'record_type': type,
            'payload': {'version': 1, 'data': jsonDecode(raw)},
            'updated_at': updatedAt.toUtc().toIso8601String(),
          }, onConflict: 'owner_id,record_type');
          meta[type] = {
            'local_hash': hash,
            'synced_hash': hash,
            'local_changed_at': updatedAt.toUtc().toIso8601String(),
            'remote_updated_at': updatedAt.toUtc().toIso8601String(),
          };
        }
        await _writeMeta(meta);
        if (type == 'photos') {
          final local = await _readLocal(type);
          if (local != null) {
            final decoded = jsonDecode(local);
            final rawPhotos = decoded is List
                ? decoded
                : (decoded as Map<String, dynamic>)['photos'] as List? ??
                      const [];
            await _syncPhotoFiles(
              backend,
              rawPhotos,
              useRemote || remoteIsNewer,
              syncCipher,
            );
          }
        }
      }
      await _writeQueue(const []);
      pending = 0;
      return Success(SyncSummary(pending: pending, syncedAt: DateTime.now()));
    } on PostgrestException catch (error) {
      return Failure(
        AppFailure(
          message:
              'Nao foi possivel sincronizar agora. Seus dados locais foram preservados.',
          code: 'sync_remote_failed',
          cause: error,
        ),
      );
    } on StorageException catch (error) {
      return Failure(
        AppFailure(
          message:
              'Nao foi possivel enviar as fotos. Seus dados locais foram preservados.',
          code: 'sync_storage_failed',
          cause: error,
        ),
      );
    } on Exception catch (error) {
      return Failure(
        AppFailure(
          message:
              'Sincronizacao indisponivel. Tente novamente quando estiver conectado.',
          code: 'sync_failed',
          cause: error,
        ),
      );
    }
  }

  Future<Result<List<_QueueItem>>> _refreshQueue() async {
    try {
      final meta = await _readMeta();
      final queue = <_QueueItem>[];
      for (final type in _recordTypes) {
        final raw = await _readLocal(type);
        if (raw == null) continue;
        final hash = await _hash(raw);
        final item = meta[type] as Map<String, dynamic>?;
        if (item?['local_hash'] != hash) {
          final changedAt = DateTime.now().toUtc();
          meta[type] = {
            ...?item,
            'local_hash': hash,
            'local_changed_at': changedAt.toIso8601String(),
          };
          queue.add(_QueueItem(type: type, hash: hash, changedAt: changedAt));
        } else if (item?['synced_hash'] != hash) {
          queue.add(
            _QueueItem(
              type: type,
              hash: hash,
              changedAt:
                  DateTime.tryParse(
                    item?['local_changed_at'] as String? ?? '',
                  ) ??
                  DateTime.now().toUtc(),
            ),
          );
        }
      }
      await _writeMeta(meta);
      await _writeQueue(queue);
      return Success(queue);
    } on Exception {
      return const Failure(
        AppFailure(
          message: 'Nao foi possivel preparar a fila de sincronizacao.',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _readMeta() async {
    final stored = await database.read(_metaKey);
    if (stored case Success<String?>(:final value) when value != null) {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return <String, dynamic>{};
  }

  Future<void> _writeMeta(Map<String, dynamic> value) async {
    await database.write(_metaKey, jsonEncode(value));
  }

  Future<void> _writeQueue(List<_QueueItem> items) async {
    await database.write(
      _queueKey,
      jsonEncode({
        'version': _queueVersion,
        'items': items.map((item) => item.toJson()).toList(),
      }),
    );
  }

  Future<String?> _readLocal(String type) async {
    final key = switch (type) {
      'profile' => 'profile:$ownerId',
      'training' => 'training:$ownerId',
      'measurements' => 'measurements:$ownerId',
      'photos' => 'photos:$ownerId',
      _ => throw StateError('Unknown sync record.'),
    };
    final result = await database.read(key);
    return result.fold(onFailure: (_) => null, onSuccess: (value) => value);
  }

  Future<Result<void>> _writeLocal(String type, String raw) {
    final key = switch (type) {
      'profile' => 'profile:$ownerId',
      'training' => 'training:$ownerId',
      'measurements' => 'measurements:$ownerId',
      'photos' => 'photos:$ownerId',
      _ => throw StateError('Unknown sync record.'),
    };
    return database.write(key, raw);
  }

  Future<String> _hash(String value) async {
    final digest = await Sha256().hash(utf8.encode(value));
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<void> _syncPhotoFiles(
    SupabaseClient backend,
    List<dynamic> rawPhotos,
    bool download,
    RecordCipher syncCipher,
  ) async {
    for (final value in rawPhotos) {
      final photo = Map<String, dynamic>.from(value as Map);
      final id = photo['id'] as String;
      final fileName = photo['file_name'] as String;
      final path = '$ownerId/$fileName';
      if (download) {
        final bytes = await backend.storage.from('vero-private').download(path);
        await files.writeFromSync(id, fileName, bytes, syncCipher);
      } else {
        final bytes = await files.readForSync(id, fileName, syncCipher);
        await backend.storage
            .from('vero-private')
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'application/octet-stream',
              ),
            );
      }
    }
  }

  Future<RecordCipher> _readSyncCipher(SupabaseClient backend) async {
    final local = await database.read(_syncKey);
    if (local case Success<String?>(:final value) when value != null) {
      return RecordCipher.fromStorageKey(value);
    }
    final remote = await backend
        .from('sync_keys')
        .select('key')
        .eq('owner_id', ownerId)
        .maybeSingle();
    final stored = remote?['key'] as String?;
    final key = stored ?? _newSyncKey();
    if (stored == null) {
      await backend.from('sync_keys').upsert({
        'owner_id': ownerId,
        'key': key,
      }, onConflict: 'owner_id');
    }
    await database.write(_syncKey, key);
    return RecordCipher.fromStorageKey(key);
  }

  String _newSyncKey() => base64UrlEncode(
    Uint8List.fromList(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    ),
  );
}

class _QueueItem {
  const _QueueItem({
    required this.type,
    required this.hash,
    required this.changedAt,
  });
  final String type;
  final String hash;
  final DateTime changedAt;

  Map<String, dynamic> toJson() => {
    'type': type,
    'hash': hash,
    'changed_at': changedAt.toUtc().toIso8601String(),
  };
}
