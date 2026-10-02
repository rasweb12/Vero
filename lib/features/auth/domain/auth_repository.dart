import '../../../shared/utils/result.dart';

class Account {
  const Account({required this.id, required this.email, this.name = ''});
  final String id;
  final String email;
  final String name;
}

abstract interface class AuthRepository {
  bool get configured;
  Account? get currentAccount;
  Stream<Account?> get accountChanges;
  Future<Result<void>> login(String email, String password);
  Future<Result<void>> register(String name, String email, String password);
  Future<Result<void>> sendRecovery(String email);
  Future<Result<void>> resendConfirmation(String email);
  Future<Result<void>> verifyCode(
    String email,
    String code, {
    required bool recovery,
  });
  Future<Result<void>> updatePassword(String password);
  Future<Result<void>> logout();
}
