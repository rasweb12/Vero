import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vero/features/auth/presentation/auth_controller.dart';
import 'package:vero/features/profile/data/profile_repository.dart';
import 'package:vero/features/profile/domain/usuario.dart';
import 'package:vero/features/subscription/domain/app_plan.dart';
import 'package:vero/features/subscription/presentation/plan_provider.dart';
import 'package:vero/shared/database/local_database.dart';
import 'package:vero/shared/providers/local_database_provider.dart';
import 'package:vero/shared/utils/result.dart';

import 'support/fake_auth_repository.dart';

class MemoryDatabase implements LocalDatabase {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<Result<String?>> read(String key) async => fail
      ? const Failure(AppFailure(message: 'Storage failure'))
      : Success(values[key]);
  @override
  Future<Result<void>> write(String key, String value) async {
    if (fail) return const Failure(AppFailure(message: 'Storage failure'));
    values[key] = value;
    return const Success(null);
  }

  @override
  Future<Result<void>> delete(String key) async {
    if (fail) return const Failure(AppFailure(message: 'Storage failure'));
    values.remove(key);
    return const Success(null);
  }

  @override
  Future<void> close() async {}
}

void main() {
  test(
    'profile serialization keeps private values and excludes local flags remotely',
    () {
      const user = Usuario(
        id: 'a',
        email: 'ana@example.com',
        name: 'Ana',
        goalWeight: 70.5,
        weeklyGoal: 4,
        reminders: true,
        pendingUpload: true,
      );
      final restored = Usuario.fromJson(
        jsonDecode(jsonEncode(user.toLocalJson())) as Map<String, dynamic>,
      );
      expect(restored.goalWeight, 70.5);
      expect(restored.pendingUpload, isTrue);
      expect(user.toRemoteJson().containsKey('pending_upload'), isFalse);
      expect(user.toRemoteJson().containsKey('email'), isFalse);
      expect(user.toRemoteJson().containsKey('plan'), isFalse);
    },
  );

  test('cached profile loads offline and never crosses accounts', () async {
    final database = MemoryDatabase();
    const user = Usuario(id: 'user-a', email: 'old@example.com', name: 'Ana');
    database.values['profile:user-a'] = jsonEncode(user.toLocalJson());
    final repository = ProfileRepository(database, null);
    final result =
        await repository.load(FakeAuthRepository.account) as Success<Usuario>;
    expect(result.value.email, 'ana@example.com');
    database.values['profile:user-a'] = jsonEncode({
      ...user.toLocalJson(),
      'id': 'user-b',
    });
    expect(
      (await repository.load(FakeAuthRepository.account)).isFailure,
      isTrue,
    );
    database.fail = true;
    expect(
      (await repository.load(FakeAuthRepository.account)).isFailure,
      isTrue,
    );
  });

  test('free limits and premium capabilities follow the business rules', () {
    expect(AppPlan.free.photoLimit, 5);
    expect(AppPlan.free.measurementLimit, 5);
    expect(AppPlan.free.historyMonths, 3);
    expect(AppPlan.free.cloudBackup, isFalse);
    expect(AppPlan.monthly.photoLimit, isNull);
    expect(AppPlan.monthly.reports, isTrue);
    expect(AppPlan.annual.adaptiveReminders, isTrue);
    expect(AppPlan.parse('unknown'), AppPlan.free);
  });

  test(
    'local plan persists per account and defaults to free on errors',
    () async {
      final auth = FakeAuthRepository()
        ..currentAccount = FakeAuthRepository.account;
      final database = MemoryDatabase();
      database.values['plan:user-a'] = 'annual';
      database.values['plan:user-b'] = 'monthly';
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          localDatabaseProvider.overrideWithValue(database),
        ],
      );
      final subscription = container.listen(planProvider, (_, next) {});
      expect(
        (await container.read(planProvider.future) as Success<AppPlan>).value,
        AppPlan.annual,
      );
      database.fail = true;
      container.invalidate(planProvider);
      await container.read(planProvider.future);
      expect(container.read(effectivePlanProvider), AppPlan.free);
      subscription.close();
      container.dispose();
      await auth.changes.close();
    },
  );
}
