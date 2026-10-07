import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/utils/result.dart';

AppFailure mapSupabaseAuthFailure(AuthException error) {
  var code = error.code;
  var providerMessage = error.message;

  // GoTrue wraps HTTP 5xx bodies in AuthRetryableFetchException without a code.
  try {
    final payload = jsonDecode(providerMessage);
    if (payload is Map<String, dynamic>) {
      final responseCode = payload['code'] ?? payload['error_code'];
      final responseMessage = payload['message'] ?? payload['msg'];
      if (responseCode is String) code ??= responseCode;
      if (responseMessage is String) providerMessage = responseMessage;
    }
  } on FormatException {
    // Regular SDK exceptions already contain a plain-text message.
  }

  final status = int.tryParse(error.statusCode ?? '');
  final emailDeliveryFailed = const {
    'Error sending confirmation email',
    'Error sending confirmation mail',
    'Error sending recovery email',
  }.contains(providerMessage);
  if (emailDeliveryFailed || code == 'email_address_not_authorized') {
    return const AppFailure(
      message:
          'Nao conseguimos enviar o e-mail agora. Tente novamente mais tarde.',
      code: 'email_send_failed',
    );
  }

  if (status == 429) code ??= 'over_request_rate_limit';
  final message = switch (code) {
    'invalid_credentials' => 'Confira seu e-mail e sua senha.',
    'email_not_confirmed' => 'Confirme seu e-mail antes de entrar.',
    'user_already_exists' || 'email_exists' =>
      'Nao foi possivel cadastrar. Tente entrar ou recuperar sua senha.',
    'email_address_invalid' => 'Confira o endereco de e-mail informado.',
    'email_provider_disabled' =>
      'O cadastro por e-mail esta temporariamente indisponivel.',
    'signup_disabled' => 'Novos cadastros estao temporariamente indisponiveis.',
    'weak_password' =>
      'Escolha uma senha mais forte, com pelo menos 8 caracteres.',
    'otp_expired' =>
      'Codigo invalido ou expirado. Solicite outro e tente novamente.',
    'over_email_send_rate_limit' || 'over_request_rate_limit' =>
      'Aguarde alguns minutos antes de tentar novamente.',
    _ when status != null && status >= 500 =>
      'O servico de conta esta temporariamente indisponivel. Tente novamente mais tarde.',
    _ when error is AuthRetryableFetchException =>
      'Nao foi possivel conectar. Confira sua conexao e tente novamente.',
    _ => 'Nao foi possivel concluir. Confira os dados e tente novamente.',
  };
  return AppFailure(message: message, code: code);
}
