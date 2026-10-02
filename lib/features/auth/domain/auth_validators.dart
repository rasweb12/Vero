class AuthValidators {
  const AuthValidators._();

  static String? email(String? value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Informe um e-mail valido.';

  static String? password(String? value) =>
      (value?.length ?? 0) >= 8 ? null : 'Use pelo menos 8 caracteres.';

  static String? requiredText(String? value) =>
      (value?.trim().isNotEmpty ?? false) ? null : 'Preencha este campo.';

  static String? code(String? value) =>
      RegExp(r'^\d{6,10}$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Informe o codigo recebido por e-mail.';
}
