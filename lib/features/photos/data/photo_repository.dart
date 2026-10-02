import 'dart:convert';
import 'dart:typed_data';

import '../../../shared/database/local_database.dart';
import '../../../shared/utils/record_id.dart';
import '../../../shared/utils/result.dart';
import '../../subscription/domain/app_plan.dart';
import '../domain/progress_photo.dart';
import 'private_photo_store.dart';

class PhotoRepository {
  const PhotoRepository(this.database, this.files, this.ownerId);
  final LocalDatabase database;
  final PrivatePhotoStore files;
  final String ownerId;

  Future<Result<void>> markPending(DateTime? date) => database.write(
    'photo-import:pending',
    date == null
        ? ''
        : jsonEncode({
            'owner': ownerId,
            'date': date.toUtc().toIso8601String(),
          }),
  );

  Future<DateTime?> pendingDate() async {
    final stored = await database.read('photo-import:pending');
    if (stored is! Success<String?> ||
        stored.value == null ||
        stored.value!.isEmpty) {
      return null;
    }
    try {
      final request = jsonDecode(stored.value!) as Map<String, dynamic>;
      return request['owner'] == ownerId
          ? DateTime.tryParse(request['date'] as String)?.toLocal()
          : null;
    } on Object {
      return null;
    }
  }

  Future<Result<List<ProgressPhoto>>> load() async {
    final stored = await database.read('photos:$ownerId');
    return stored.fold(
      onFailure: (failure) => Failure(failure),
      onSuccess: (value) {
        if (value == null) return const Success([]);
        try {
          final photos =
              (jsonDecode(value) as List)
                  .map(
                    (row) =>
                        ProgressPhoto.fromJson(row as Map<String, dynamic>),
                  )
                  .toList()
                ..sort((a, b) => a.date.compareTo(b.date));
          return Success(photos);
        } on Object {
          return const Failure(
            AppFailure(
              message:
                  'Nao foi possivel ler a galeria. Os arquivos foram preservados.',
            ),
          );
        }
      },
    );
  }

  Future<Result<void>> add(Uint8List bytes, DateTime date, AppPlan plan) async {
    final loaded = await load();
    if (loaded case Failure<List<ProgressPhoto>>(:final failure)) {
      return Failure(failure);
    }
    final photos = (loaded as Success<List<ProgressPhoto>>).value;
    if (plan.photoLimit != null && photos.length >= plan.photoLimit!) {
      return const Failure(
        AppFailure(
          message:
              'O plano Free permite ate 5 fotos. Exclua uma foto ou escolha outro plano.',
          code: 'plan_limit',
        ),
      );
    }
    if (date.isAfter(DateTime.now()) || date.isBefore(DateTime(1900))) {
      return const Failure(AppFailure(message: 'Confira a data da foto.'));
    }
    String? created;
    try {
      final id = newRecordId();
      created = await files.save(id, bytes);
      final photo = ProgressPhoto(id: id, date: date, fileName: created);
      final saved = await database.write(
        'photos:$ownerId',
        jsonEncode([...photos, photo].map((item) => item.toJson()).toList()),
      );
      if (saved.isFailure) await files.delete(created);
      return saved;
    } on Exception {
      // A failed manifest write must not leave an accessible unindexed photo.
      if (created != null) {
        try {
          await files.delete(created);
        } on Exception {
          /* Encrypted orphan; no plaintext was written. */
        }
      }
      return const Failure(
        AppFailure(message: 'Nao foi possivel salvar a foto neste aparelho.'),
      );
    }
  }

  Future<Result<void>> remove(String id) async {
    final loaded = await load();
    if (loaded case Failure<List<ProgressPhoto>>(:final failure)) {
      return Failure(failure);
    }
    final photos = (loaded as Success<List<ProgressPhoto>>).value;
    final photo = photos.where((item) => item.id == id).firstOrNull;
    if (photo == null) return const Success(null);
    final saved = await database.write(
      'photos:$ownerId',
      jsonEncode(
        photos
            .where((item) => item.id != id)
            .map((item) => item.toJson())
            .toList(),
      ),
    );
    if (saved.isFailure) return saved;
    try {
      await files.delete(photo.fileName);
      return const Success(null);
    } on Exception {
      return const Failure(
        AppFailure(
          message:
              'Foto removida da galeria. Nao foi possivel limpar o arquivo privado.',
          code: 'cleanup_pending',
        ),
      );
    }
  }

  Future<Uint8List> read(String id) async {
    final loaded = await load();
    if (loaded is! Success<List<ProgressPhoto>>) {
      throw StateError('Gallery unavailable.');
    }
    final photo = loaded.value.where((item) => item.id == id).firstOrNull;
    if (photo == null) throw StateError('Photo unavailable.');
    return files.read(photo.id, photo.fileName);
  }
}
