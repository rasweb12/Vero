import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';
import '../../../shared/utils/result.dart';

class AppLockState {
  const AppLockState({this.ready = false, this.enabled = false});
  final bool ready;
  final bool enabled;
}

final appLockProvider = StateNotifierProvider<AppLockController, AppLockState>(
  (ref) => AppLockController(ref.watch(sharedPreferencesProvider)),
);

class AppLockController extends StateNotifier<AppLockState> {
  AppLockController(this.preferences) : super(const AppLockState()) {
    ready = _load();
  }

  static const _key = 'security:app_lock_enabled';
  final SharedPreferences preferences;
  final LocalAuthentication authentication = LocalAuthentication();
  late final Future<void> ready;

  Future<void> _load() async {
    state = AppLockState(
      ready: true,
      enabled: preferences.getBool(_key) ?? false,
    );
  }

  Future<Result<void>> setEnabled(bool enabled) async {
    await ready;
    if (enabled) {
      try {
        final supported = await authentication.isDeviceSupported();
        if (!supported) {
          return const Failure(
            AppFailure(
              message:
                  'Este aparelho nao oferece bloqueio por biometria ou senha.',
            ),
          );
        }
        final authenticated = await authentication.authenticate(
          localizedReason: 'Confirme para proteger seus dados no Vero.',
          biometricOnly: false,
          sensitiveTransaction: true,
          persistAcrossBackgrounding: true,
        );
        if (!authenticated) {
          return const Failure(AppFailure(message: 'Bloqueio nao ativado.'));
        }
      } on Object {
        return const Failure(
          AppFailure(
            message: 'Nao foi possivel validar o bloqueio deste aparelho.',
          ),
        );
      }
    }
    await preferences.setBool(_key, enabled);
    state = AppLockState(ready: true, enabled: enabled);
    return const Success(null);
  }

  Future<bool> authenticate() async {
    try {
      return await authentication.authenticate(
        localizedReason: 'Desbloqueie o Vero para continuar.',
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } on Object {
      return false;
    }
  }
}
