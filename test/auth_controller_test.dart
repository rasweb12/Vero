import 'package:flutter_test/flutter_test.dart';
import 'package:vero/features/auth/data/supabase_auth_repository.dart';
import 'package:vero/features/auth/domain/auth_validators.dart';
import 'package:vero/features/auth/presentation/auth_controller.dart';
import 'package:vero/shared/providers/router_provider.dart';

import 'support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late AuthController controller;
  setUp(() {
    repository = FakeAuthRepository();
    controller = AuthController(repository);
  });
  tearDown(() async {
    controller.dispose();
    await repository.changes.close();
  });

  test('guards private routes and waits for valid recovery session', () {
    expect(authRedirect(const AuthSession(), '/profile'), '/login');
    expect(authRedirect(const AuthSession(), '/plans'), '/login');
    expect(authRedirect(const AuthSession(), '/new-password'), '/login');
    expect(
      authRedirect(const AuthSession(recovering: true), '/recovery'),
      isNull,
    );
    expect(
      authRedirect(
        const AuthSession(account: FakeAuthRepository.account),
        '/login',
      ),
      '/home',
    );
  });

  test('recovery stays gated until password update succeeds', () async {
    await controller.verifyRecovery('ana@example.com', '123456');
    expect(authRedirect(controller.state, '/profile'), '/new-password');
    repository.fail = true;
    expect((await controller.updatePassword('new-password')).isFailure, isTrue);
    expect(controller.state.recovering, isTrue);
    repository.fail = false;
    await controller.updatePassword('new-password');
    expect(controller.state.recovering, isFalse);
    expect(authRedirect(controller.state, '/new-password'), '/home');
  });

  test('invalid recovery code does not open private routes', () async {
    repository.fail = true;
    await controller.verifyRecovery('ana@example.com', '123456');
    expect(controller.state.account, isNull);
    expect(controller.state.recovering, isFalse);
  });

  test('restores account and handles logout success and failure', () async {
    await repository.login('', '');
    final restored = AuthController(repository);
    expect(restored.state.account?.id, 'user-a');
    restored.dispose();
    repository.fail = true;
    await controller.logout();
    expect(controller.state.account, isNotNull);
    repository.fail = false;
    await controller.logout();
    expect(controller.state.account, isNull);
  });

  test(
    'missing configuration returns failure without creating account',
    () async {
      const auth = SupabaseAuthRepository(null);
      expect(auth.configured, isFalse);
      expect(
        (await auth.login('ana@example.com', 'password')).isFailure,
        isTrue,
      );
      expect(auth.currentAccount, isNull);
    },
  );

  test('validators reject invalid email, short password and malformed OTP', () {
    expect(AuthValidators.email('ana@example.com'), isNull);
    expect(AuthValidators.email('ana@'), isNotNull);
    expect(AuthValidators.password('short'), isNotNull);
    expect(AuthValidators.password('long-enough'), isNull);
    expect(AuthValidators.code('12345678'), isNull);
    expect(AuthValidators.code('123'), isNotNull);
  });
}
