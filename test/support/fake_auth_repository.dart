import 'dart:async';

import 'package:vero/features/auth/domain/auth_repository.dart';
import 'package:vero/shared/utils/result.dart';

class FakeAuthRepository implements AuthRepository {
  final changes = StreamController<Account?>.broadcast(sync: true);
  @override
  Account? currentAccount;
  @override
  bool configured = true;
  bool fail = false;
  int loginCalls = 0;

  static const account = Account(
    id: 'user-a',
    email: 'ana@example.com',
    name: 'Ana',
  );

  @override
  Stream<Account?> get accountChanges => changes.stream;

  Result<void> get result => fail
      ? const Failure(AppFailure(message: 'Falha de teste.'))
      : const Success(null);

  @override
  Future<Result<void>> login(String email, String password) async {
    loginCalls++;
    if (!fail) {
      currentAccount = account;
      changes.add(account);
    }
    return result;
  }

  @override
  Future<Result<void>> register(
    String name,
    String email,
    String password,
  ) async => result;

  @override
  Future<Result<void>> sendRecovery(String email) async => result;

  @override
  Future<Result<void>> resendConfirmation(String email) async => result;

  @override
  Future<Result<void>> verifyCode(
    String email,
    String code, {
    required bool recovery,
  }) async {
    if (!fail) {
      currentAccount = account;
      changes.add(account);
    }
    return result;
  }

  @override
  Future<Result<void>> updatePassword(String password) async => result;

  @override
  Future<Result<void>> logout() async {
    if (!fail) {
      currentAccount = null;
      changes.add(null);
    }
    return result;
  }
}
