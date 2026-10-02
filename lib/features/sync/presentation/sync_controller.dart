import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/local_database_provider.dart';
import '../../../shared/utils/result.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../photos/presentation/photo_controller.dart';
import '../../subscription/domain/app_plan.dart';
import '../../subscription/presentation/plan_provider.dart';
import '../data/sync_repository.dart';
import '../domain/sync_models.dart';

final syncRepositoryProvider = FutureProvider<SyncRepository?>((ref) async {
  final account = ref.watch(authControllerProvider).account;
  final client = ref.watch(supabaseClientProvider);
  if (account == null || client == null) return null;
  return SyncRepository(
    database: ref.watch(localDatabaseProvider),
    client: client,
    files: await ref.watch(photoStoreProvider.future),
    ownerId: account.id,
  );
});

final syncControllerProvider = StateNotifierProvider<SyncController, SyncState>(
  (ref) {
    final repository = ref.watch(syncRepositoryProvider.future);
    return SyncController(repository, () => ref.read(effectivePlanProvider));
  },
);

class SyncController extends StateNotifier<SyncState> {
  SyncController(this.repository, this.plan) : super(const SyncState()) {
    ready = _loadPending();
  }

  final Future<SyncRepository?> repository;
  final AppPlan Function() plan;
  late final Future<void> ready;
  Future<void> _pending = Future.value();

  Future<void> _loadPending() async {
    try {
      final store = await repository;
      if (store == null || !mounted) return;
      final result = await store.pendingCount();
      if (!mounted) return;
      if (result case Success<int>(:final value)) {
        state = state.copyWith(pending: value);
      }
    } on Exception {
      // The sync indicator must never prevent the rest of the app from opening.
    }
  }

  Future<void> syncNow() {
    final operation = _pending.then((_) async {
      await ready;
      if (!mounted) return;
      if (!plan().cloudBackup) {
        state = state.copyWith(
          status: SyncStatus.requiresPlan,
          message: 'O backup em nuvem esta disponivel no Premium.',
        );
        return;
      }
      state = state.copyWith(status: SyncStatus.syncing, message: null);
      try {
        final store = await repository;
        if (store == null) {
          state = state.copyWith(
            status: SyncStatus.offline,
            message: 'Configure o Supabase para ativar a sincronizacao.',
          );
          return;
        }
        final result = await store.sync();
        if (!mounted) return;
        state = result.fold(
          onFailure: (failure) => state.copyWith(
            status: SyncStatus.error,
            message: failure.message,
          ),
          onSuccess: (summary) => state.copyWith(
            status: SyncStatus.synced,
            pending: summary.pending,
            lastSyncedAt: summary.syncedAt,
          ),
        );
      } on Exception {
        if (mounted) {
          state = state.copyWith(
            status: SyncStatus.offline,
            message: 'Sincronizacao indisponivel no momento.',
          );
        }
      }
    });
    _pending = operation.then((_) {});
    return operation;
  }
}
