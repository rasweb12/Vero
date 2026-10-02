import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/database/isar_encryption_key_store.dart';
import '../../../shared/database/record_cipher.dart';
import '../../../shared/providers/local_database_provider.dart';
import '../../../shared/utils/result.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../subscription/domain/app_plan.dart';
import '../../subscription/presentation/plan_provider.dart';
import '../data/photo_repository.dart';
import '../data/private_photo_store.dart';
import '../domain/progress_photo.dart';

final photoStoreProvider = FutureProvider<PrivatePhotoStore>((ref) async {
  final id = ref.watch(
    authControllerProvider.select((value) => value.account?.id),
  );
  if (id == null) throw StateError('Sign in required.');
  final directory = await getApplicationSupportDirectory();
  final cipher = await RecordCipher.fromStorageKey(
    await const IsarEncryptionKeyStore().readOrCreateKey(),
  );
  return PrivatePhotoStore(directory, cipher, id);
});

final photoRepositoryProvider = FutureProvider<PhotoRepository>((ref) async {
  final id = ref.watch(
    authControllerProvider.select((value) => value.account?.id),
  );
  if (id == null) throw StateError('Sign in required.');
  final database = ref.watch(localDatabaseProvider);
  return PhotoRepository(
    database,
    await ref.watch(photoStoreProvider.future),
    id,
  );
});

final photoControllerProvider =
    StateNotifierProvider<PhotoController, AsyncValue<List<ProgressPhoto>>>((
      ref,
    ) {
      final repository = ref.watch(photoRepositoryProvider.future);
      return PhotoController(repository, () => ref.read(effectivePlanProvider));
    });
final photoBytesProvider = FutureProvider.autoDispose.family<Uint8List, String>(
  (ref, id) async {
    final repository = await ref.watch(photoRepositoryProvider.future);
    return repository.read(id);
  },
);

class PhotoController extends StateNotifier<AsyncValue<List<ProgressPhoto>>> {
  PhotoController(this.repository, this.plan) : super(const AsyncLoading()) {
    ready = reload();
  }
  final Future<PhotoRepository> repository;
  final AppPlan Function() plan;
  late final Future<void> ready;
  Future<void> _pending = Future.value();
  final _picker = ImagePicker();

  Future<void> reload() async {
    try {
      final result = await (await repository).load();
      if (mounted) {
        state = result.fold(
          onFailure: (failure) =>
              AsyncError(failure.message, StackTrace.current),
          onSuccess: AsyncData.new,
        );
      }
    } on Object catch (error, trace) {
      if (mounted) state = AsyncError(error, trace);
    }
  }

  Future<Result<void>> _run(
    Future<Result<void>> Function(PhotoRepository) action,
  ) {
    final operation = _pending.then((_) async {
      await ready;
      if (!mounted || state.hasError) {
        return const Failure<void>(AppFailure(message: 'Sessao encerrada.'));
      }
      try {
        final result = await action(await repository);
        await reload();
        return result;
      } on Exception {
        return const Failure<void>(
          AppFailure(message: 'Nao foi possivel acessar a foto.'),
        );
      }
    });
    _pending = operation.then((_) {});
    return operation;
  }

  Future<Result<void>> importPhoto(XFile source, DateTime date) =>
      _run((repository) async {
        if (await source.length() > 20 * 1024 * 1024) {
          return const Failure(
            AppFailure(message: 'Escolha uma foto de ate 20 MB.'),
          );
        }
        final normalized = await normalizePhoto(await source.readAsBytes());
        if (!mounted) {
          return const Failure(AppFailure(message: 'Sessao encerrada.'));
        }
        return repository.add(normalized, date, plan());
      });

  Future<Result<void>> pick(ImageSource source, DateTime date) async {
    try {
      final store = await repository;
      final marked = await store.markPending(date);
      if (marked.isFailure || !mounted) return marked;
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (file == null) {
        await store.markPending(null);
        return const Success(null);
      }
      final result = await importPhoto(file, date);
      await _removePickerCache(file);
      await store.markPending(null);
      return result;
    } on PlatformException catch (error) {
      final denied = error.code.toLowerCase().contains('access_denied');
      return Failure(
        AppFailure(
          message: denied
              ? 'Permissao negada. Voce pode autorizar o acesso nas configuracoes do aparelho.'
              : 'Camera ou galeria indisponivel neste aparelho.',
        ),
      );
    } on Object {
      return const Failure(
        AppFailure(message: 'Nao foi possivel abrir a foto. Tente novamente.'),
      );
    }
  }

  Future<Result<void>> recoverLostPhoto() async {
    if (!Platform.isAndroid) return const Success(null);
    try {
      final store = await repository;
      final pending = await store.pendingDate();
      if (pending == null || !mounted) return const Success(null);
      final response = await _picker.retrieveLostData();
      if (response.exception != null) {
        return const Failure(
          AppFailure(message: 'Nao foi possivel recuperar a selecao da foto.'),
        );
      }
      for (final file in response.files ?? <XFile>[]) {
        final result = await importPhoto(file, pending);
        await _removePickerCache(file);
        if (result.isFailure) return result;
      }
      await store.markPending(null);
      return const Success(null);
    } on PlatformException {
      return const Failure(
        AppFailure(
          message:
              'Nao foi possivel recuperar a foto. Tente seleciona-la novamente.',
        ),
      );
    } on Object {
      return const Failure(
        AppFailure(message: 'Nao foi possivel recuperar a foto.'),
      );
    }
  }

  Future<Result<void>> remove(String id) =>
      _run((repository) => repository.remove(id));

  Future<void> _removePickerCache(XFile source) async {
    // Delete only the plugin's copy inside this app's cache, never gallery originals.
    try {
      final file = File(source.path);
      if (!await file.exists()) return;
      final root = await (await getTemporaryDirectory()).resolveSymbolicLinks();
      final resolved = await file.resolveSymbolicLinks();
      final prefix = '$root${Platform.pathSeparator}';
      final inside = Platform.isWindows
          ? resolved.toLowerCase().startsWith(prefix.toLowerCase())
          : resolved.startsWith(prefix);
      if (inside) await file.delete();
    } on Exception {
      /* The OS also manages cache eviction. */
    }
  }
}
