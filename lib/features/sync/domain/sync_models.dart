import '../../subscription/domain/app_plan.dart';

enum SyncStatus { idle, syncing, synced, offline, requiresPlan, error }

class SyncState {
  const SyncState({
    this.status = SyncStatus.idle,
    this.pending = 0,
    this.lastSyncedAt,
    this.message,
  });

  final SyncStatus status;
  final int pending;
  final DateTime? lastSyncedAt;
  final String? message;

  SyncState copyWith({
    SyncStatus? status,
    int? pending,
    DateTime? lastSyncedAt,
    String? message,
  }) => SyncState(
    status: status ?? this.status,
    pending: pending ?? this.pending,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    message: message,
  );
}

class SyncSummary {
  const SyncSummary({required this.pending, required this.syncedAt});
  final int pending;
  final DateTime syncedAt;
}

AppPlan verifiedPlanFromEntitlements(Iterable<String> products) {
  if (products.any((id) => id == 'premium_anual')) return AppPlan.annual;
  if (products.any((id) => id == 'premium_mensal')) return AppPlan.monthly;
  return AppPlan.free;
}
