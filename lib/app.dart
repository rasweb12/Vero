import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/presentation/auth_controller.dart';
import 'features/settings/presentation/security_provider.dart';
import 'shared/providers/router_provider.dart';
import 'shared/providers/theme_mode_provider.dart';
import 'shared/theme/app_theme.dart';

class VeroApp extends ConsumerWidget {
  const VeroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Vero',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          AppLockGate(child: child ?? const SizedBox.shrink()),
    );
  }
}

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _unlocked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final enabled = ref.read(appLockProvider).enabled;
      final account = ref.read(authControllerProvider).account;
      if (enabled && account != null && mounted) {
        setState(() => _unlocked = false);
      }
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final authenticated = await ref
        .read(appLockProvider.notifier)
        .authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _unlocked = authenticated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(authControllerProvider).account;
    final lock = ref.watch(appLockProvider);
    ref.listen<AppLockState>(appLockProvider, (previous, next) {
      if (previous?.enabled != next.enabled && next.enabled) {
        setState(() => _unlocked = true);
      }
      if (!next.enabled) setState(() => _unlocked = true);
    });

    if (account == null || !lock.enabled || _unlocked) return widget.child;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _unlock();
    });
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 16),
                const Text('Vero bloqueado'),
                const SizedBox(height: 8),
                Text(
                  _authenticating
                      ? 'Aguardando confirmacao...'
                      : 'Confirme sua identidade para continuar.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _authenticating ? null : _unlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Desbloquear'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
