import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/utils/result.dart';
import '../../../shared/widgets/vero_text_field.dart';
import '../domain/auth_validators.dart';
import 'auth_controller.dart';

enum AuthPageMode { login, register, recovery, confirm, newPassword }

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({required this.mode, this.email = '', super.key});
  final AuthPageMode mode;
  final String email;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _hidePassword = true;
  bool _codeSent = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _email.text = widget.email;
    if (widget.mode == AuthPageMode.confirm) {
      _notice =
          'Confira sua caixa de entrada e o spam. Se nao chegar, aguarde um pouco antes de reenviar.';
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirmation, _code]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final repository = ref.read(authRepositoryProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final email = _email.text.trim();
    final result = switch (widget.mode) {
      AuthPageMode.login => await repository.login(email, _password.text),
      AuthPageMode.register => await repository.register(
        _name.text.trim(),
        email,
        _password.text,
      ),
      AuthPageMode.confirm => await repository.verifyCode(
        email,
        _code.text.trim(),
        recovery: false,
      ),
      AuthPageMode.recovery =>
        _codeSent
            ? await controller.verifyRecovery(email, _code.text.trim())
            : await repository.sendRecovery(email),
      AuthPageMode.newPassword => await controller.updatePassword(
        _password.text,
      ),
    };
    if (!mounted) return;
    setState(() => _busy = false);
    if (result case Failure<void>(:final failure)) {
      setState(() => _error = failure.message);
      return;
    }
    switch (widget.mode) {
      case AuthPageMode.register:
        if (repository.currentAccount == null) {
          context.goNamed('confirm', extra: email);
        } else {
          controller.syncCurrentAccount();
        }
      case AuthPageMode.login || AuthPageMode.confirm:
        controller.syncCurrentAccount();
      case AuthPageMode.recovery:
        if (!_codeSent) {
          setState(() {
            _codeSent = true;
            _notice =
                'Se houver uma conta com este e-mail, voce recebera um codigo.';
          });
        }
      case AuthPageMode.newPassword:
        break;
    }
  }

  Future<void> _resendConfirmation() async {
    final emailError = AuthValidators.email(_email.text);
    if (_busy || emailError != null) {
      if (emailError != null) setState(() => _error = emailError);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final result = await ref
        .read(authRepositoryProvider)
        .resendConfirmation(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      result.fold(
        onFailure: (failure) => _error = failure.message,
        onSuccess: (_) => _notice =
            'Se houver um cadastro pendente, enviaremos um novo codigo.',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final hasPassword = [
      AuthPageMode.login,
      AuthPageMode.register,
      AuthPageMode.newPassword,
    ].contains(mode);
    final hasCode =
        mode == AuthPageMode.confirm ||
        (mode == AuthPageMode.recovery && _codeSent);
    final title = switch (mode) {
      AuthPageMode.login => 'Entrar',
      AuthPageMode.register => 'Criar conta',
      AuthPageMode.recovery => 'Recuperar senha',
      AuthPageMode.confirm => 'Confirmar e-mail',
      AuthPageMode.newPassword => 'Nova senha',
    };
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Vero'),
          leading:
              mode == AuthPageMode.login || mode == AuthPageMode.newPassword
              ? null
              : IconButton(
                  tooltip: 'Voltar para entrar',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _busy ? null : () => context.goNamed('login'),
                ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mode == AuthPageMode.login
                        ? 'Seu ritmo. Seus resultados.'
                        : mode == AuthPageMode.confirm
                        ? 'Digite o codigo que enviamos para seu e-mail.'
                        : mode == AuthPageMode.newPassword
                        ? 'Escolha uma nova senha para sua conta.'
                        : mode == AuthPageMode.recovery
                        ? 'Vamos ajudar voce a voltar.'
                        : 'Um espaco para cuidar da sua evolucao.',
                  ),
                  const SizedBox(height: 32),
                  AutofillGroup(
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (mode == AuthPageMode.register) ...[
                            VeroTextField(
                              labelText: 'Nome',
                              controller: _name,
                              enabled: !_busy,
                              validator: (value) =>
                                  (value?.trim().length ?? 0) > 80
                                  ? 'Use ate 80 caracteres.'
                                  : AuthValidators.requiredText(value),
                              autofillHints: const [AutofillHints.name],
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (mode != AuthPageMode.newPassword) ...[
                            VeroTextField(
                              labelText: 'E-mail',
                              controller: _email,
                              enabled: !_busy && !_codeSent,
                              validator: AuthValidators.email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (hasPassword) ...[
                            TextFormField(
                              controller: _password,
                              enabled: !_busy,
                              obscureText: _hidePassword,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: [
                                mode == AuthPageMode.login
                                    ? AutofillHints.password
                                    : AutofillHints.newPassword,
                              ],
                              validator: mode == AuthPageMode.login
                                  ? AuthValidators.requiredText
                                  : AuthValidators.password,
                              decoration: InputDecoration(
                                labelText: 'Senha',
                                suffixIcon: IconButton(
                                  tooltip: _hidePassword
                                      ? 'Mostrar senha'
                                      : 'Ocultar senha',
                                  onPressed: () => setState(
                                    () => _hidePassword = !_hidePassword,
                                  ),
                                  icon: Icon(
                                    _hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (mode == AuthPageMode.register ||
                              mode == AuthPageMode.newPassword) ...[
                            VeroTextField(
                              labelText: 'Confirmar senha',
                              controller: _confirmation,
                              enabled: !_busy,
                              obscureText: true,
                              validator: (value) => value == _password.text
                                  ? null
                                  : 'As senhas precisam ser iguais.',
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (hasCode) ...[
                            VeroTextField(
                              labelText: 'Codigo do e-mail',
                              controller: _code,
                              enabled: !_busy,
                              validator: AuthValidators.code,
                              keyboardType: TextInputType.number,
                              autofillHints: const [AutofillHints.oneTimeCode],
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          if (_notice != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(_notice!),
                              ),
                            ),
                          ElevatedButton(
                            onPressed: _busy ? null : _submit,
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    mode == AuthPageMode.recovery
                                        ? (_codeSent
                                              ? 'Confirmar codigo'
                                              : 'Enviar codigo')
                                        : title,
                                  ),
                          ),
                          if (mode == AuthPageMode.confirm)
                            TextButton(
                              onPressed: _busy ? null : _resendConfirmation,
                              child: const Text('Reenviar codigo'),
                            ),
                          if (mode == AuthPageMode.login) ...[
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => context.goNamed('recovery'),
                              child: const Text('Esqueci minha senha'),
                            ),
                            const Divider(height: 32),
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => context.goNamed('register'),
                              child: const Text('Criar conta'),
                            ),
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => context.goNamed('confirm'),
                              child: const Text(
                                'Ja tenho um codigo de confirmacao',
                              ),
                            ),
                          ],
                          if (mode == AuthPageMode.recovery && _codeSent)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _codeSent = false;
                                      _code.clear();
                                      _notice = null;
                                    }),
                              child: const Text(
                                'Alterar e-mail ou solicitar outro codigo',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
