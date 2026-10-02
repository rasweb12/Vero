import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/utils/result.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthSession>(
      (ref) => AuthController(ref.watch(authRepositoryProvider)),
    );

class AuthSession {
  const AuthSession({this.account, this.recovering = false});
  final Account? account;
  final bool recovering;
}

class AuthController extends StateNotifier<AuthSession> {
  AuthController(this.repository)
    : super(AuthSession(account: repository.currentAccount)) {
    _subscription = repository.accountChanges.listen(
      (account) {
        state = AuthSession(
          account: account,
          recovering: account != null && state.recovering,
        );
      },
      onError: (Object error) {
        // Transient refresh failures must not discard the local profile or session.
      },
    );
  }

  final AuthRepository repository;
  late final StreamSubscription<Account?> _subscription;

  Future<Result<void>> verifyRecovery(String email, String code) async {
    state = AuthSession(account: state.account, recovering: true);
    final result = await repository.verifyCode(email, code, recovery: true);
    if (mounted) {
      state = AuthSession(
        account: repository.currentAccount,
        recovering: result.isSuccess,
      );
    }
    return result;
  }

  Future<Result<void>> updatePassword(String password) async {
    final result = await repository.updatePassword(password);
    if (mounted && result.isSuccess) {
      state = AuthSession(account: repository.currentAccount);
    }
    return result;
  }

  Future<Result<void>> logout() async {
    final result = await repository.logout();
    if (mounted && result.isSuccess) state = const AuthSession();
    return result;
  }

  /// Reconciles the router state with the SDK after a successful auth call.
  /// The auth stream normally does this, but an explicit update avoids a
  /// frame where the user remains on the form while the session is valid.
  void syncCurrentAccount() {
    if (mounted) {
      state = AuthSession(
        account: repository.currentAccount,
        recovering: state.recovering,
      );
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
