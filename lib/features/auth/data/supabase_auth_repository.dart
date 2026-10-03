import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/utils/result.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this.client);
  final SupabaseClient? client;

  @override
  bool get configured => client != null;

  Account? _account(User? user) => user == null
      ? null
      : Account(
          id: user.id,
          email: user.email ?? '',
          name: user.userMetadata?['name'] as String? ?? '',
        );

  @override
  Account? get currentAccount => _account(client?.auth.currentUser);

  @override
  Stream<Account?> get accountChanges =>
      client?.auth.onAuthStateChange.map(
        (event) => _account(event.session?.user),
      ) ??
      const Stream.empty();

  Future<Result<void>> _run(
    Future<void> Function(SupabaseClient) action,
  ) async {
    final backend = client;
    if (backend == null) {
      return const Failure(
        AppFailure(
          message:
              'Nao foi possivel conectar ao servico de conta. Tente novamente mais tarde.',
          code: 'not_configured',
        ),
      );
    }
    try {
      await action(backend);
      return const Success(null);
    } on AuthException catch (error) {
      final message = switch (error.code) {
        'invalid_credentials' => 'Confira seu e-mail e sua senha.',
        'email_not_confirmed' => 'Confirme seu e-mail antes de entrar.',
        'user_already_exists' =>
          'Nao foi possivel cadastrar. Tente entrar ou recuperar sua senha.',
        'email_address_invalid' => 'Confira o endereco de e-mail informado.',
        'email_provider_disabled' =>
          'O cadastro por e-mail esta temporariamente indisponivel.',
        'signup_disabled' =>
          'Novos cadastros estao temporariamente indisponiveis.',
        'weak_password' =>
          'Escolha uma senha mais forte, com pelo menos 8 caracteres.',
        'otp_expired' =>
          'Codigo invalido ou expirado. Solicite outro e tente novamente.',
        'over_email_send_rate_limit' || 'over_request_rate_limit' =>
          'Aguarde alguns minutos antes de tentar novamente.',
        _ => 'Nao foi possivel concluir. Confira os dados e tente novamente.',
      };
      return Failure(AppFailure(message: message, code: error.code));
    } on Exception {
      return const Failure(
        AppFailure(
          message:
              'Nao foi possivel conectar. Confira sua conexao e tente novamente.',
          code: 'connection_failed',
        ),
      );
    }
  }

  @override
  Future<Result<void>> login(String email, String password) =>
      _run((backend) async {
        await backend.auth.signInWithPassword(email: email, password: password);
      });

  @override
  Future<Result<void>> register(String name, String email, String password) =>
      _run((backend) async {
        await backend.auth.signUp(
          email: email,
          password: password,
          data: {'name': name},
        );
      });

  @override
  Future<Result<void>> resendConfirmation(String email) =>
      _run((backend) async {
        await backend.auth.resend(type: OtpType.signup, email: email);
      });

  @override
  Future<Result<void>> sendRecovery(String email) => _run((backend) async {
    await backend.auth.resetPasswordForEmail(email);
  });

  @override
  Future<Result<void>> verifyCode(
    String email,
    String code, {
    required bool recovery,
  }) => _run((backend) async {
    await backend.auth.verifyOTP(
      email: email,
      token: code,
      type: recovery ? OtpType.recovery : OtpType.email,
    );
  });

  @override
  Future<Result<void>> updatePassword(String password) => _run((backend) async {
    await backend.auth.updateUser(UserAttributes(password: password));
  });

  @override
  Future<Result<void>> logout() => _run((backend) async {
    await backend.auth.signOut(scope: SignOutScope.local);
  });
}
