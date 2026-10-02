import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/local_database_provider.dart';
import '../../../shared/utils/result.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/app_plan.dart';
import 'purchase_controller.dart';

final planProvider = FutureProvider.autoDispose<Result<AppPlan>>((ref) async {
  final id = ref.watch(
    authControllerProvider.select((state) => state.account?.id),
  );
  if (id == null) return const Success(AppPlan.free);
  final stored = await ref.watch(localDatabaseProvider).read('plan:$id');
  return stored.fold(
    onFailure: (failure) => Failure(failure),
    onSuccess: (value) => Success(AppPlan.parse(value)),
  );
});

// Fail closed while loading or on storage errors. This is NOT a paid entitlement.
final effectivePlanProvider = Provider<AppPlan>((ref) {
  // Local plan selection remains useful for the paywall UI, but never grants
  // premium access. RevenueCat is the entitlement source of truth.
  return ref.watch(purchaseControllerProvider).entitledPlan;
});
