import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vero/features/auth/data/supabase_auth_failure.dart';

void main() {
  test('recognizes the confirmation email error wrapped by GoTrue HTTP 500', () {
    final failure = mapSupabaseAuthFailure(
      AuthRetryableFetchException(
        message:
            '{"code":"unexpected_failure","message":"Error sending confirmation email"}',
        statusCode: '500',
      ),
    );

    expect(failure.code, 'email_send_failed');
    expect(failure.message, contains('enviar o e-mail'));
    expect(failure.message, isNot(contains('Confira os dados')));
  });

  test('handles email delivery failures from resend and recovery', () {
    for (final message in [
      'Error sending confirmation email',
      'Error sending recovery email',
    ]) {
      final failure = mapSupabaseAuthFailure(
        AuthException(message, code: 'unexpected_failure', statusCode: '500'),
      );
      expect(failure.code, 'email_send_failed');
    }
  });

  test(
    'does not blame the address when delivery is restricted by the server',
    () {
      final failure = mapSupabaseAuthFailure(
        const AuthException(
          'Email address not authorized',
          code: 'email_address_not_authorized',
          statusCode: '403',
        ),
      );

      expect(failure.code, 'email_send_failed');
      expect(failure.message, isNot(contains('Confira os dados')));
    },
  );

  test('extracts a rate limit code embedded in the response body', () {
    final failure = mapSupabaseAuthFailure(
      const AuthException(
        '{"error_code":"over_email_send_rate_limit","msg":"Too many emails"}',
        statusCode: '429',
      ),
    );

    expect(failure.code, 'over_email_send_rate_limit');
    expect(failure.message, contains('Aguarde'));
  });

  test('handles HTTP 429 even when the server omits the error code', () {
    final failure = mapSupabaseAuthFailure(
      const AuthException('Too many requests', statusCode: '429'),
    );

    expect(failure.code, 'over_request_rate_limit');
  });

  test('hides internal details of server failures and malformed responses', () {
    for (final message in [
      '{"code":"unexpected_failure","message":"sensitive-provider-detail"}',
      '<html>internal-provider-detail</html>',
      '{invalid-json',
    ]) {
      final failure = mapSupabaseAuthFailure(
        AuthRetryableFetchException(message: message, statusCode: '503'),
      );
      expect(failure.message, contains('temporariamente indisponivel'));
      expect(failure.message, isNot(contains('provider-detail')));
    }
  });

  test(
    'treats a retryable error without HTTP response as a connection failure',
    () {
      final failure = mapSupabaseAuthFailure(
        AuthRetryableFetchException(message: 'Connection refused'),
      );

      expect(failure.message, contains('Confira sua conexao'));
    },
  );

  test('preserves login, expired OTP and existing account messages', () {
    final credentials = mapSupabaseAuthFailure(
      const AuthException('Invalid credentials', code: 'invalid_credentials'),
    );
    final otp = mapSupabaseAuthFailure(
      const AuthException('Token expired', code: 'otp_expired'),
    );
    final existing = mapSupabaseAuthFailure(
      const AuthException('Already registered', code: 'user_already_exists'),
    );

    expect(credentials.message, 'Confira seu e-mail e sua senha.');
    expect(otp.message, contains('expirado'));
    expect(existing.message, contains('recuperar sua senha'));
  });
}
