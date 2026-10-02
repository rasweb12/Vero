import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/config/app_config.dart';
import '../../../shared/utils/result.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/presentation/notification_controller.dart';
import '../../profile/domain/usuario.dart';
import '../../profile/presentation/profile_providers.dart';
import 'security_provider.dart';
import 'settings_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _profileSynced = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncProfile());
  }

  Future<void> _syncProfile() async {
    if (_profileSynced) return;
    final result = await ref.read(profileProvider.future);
    if (!mounted) return;
    if (result case Success<Usuario>(:final value)) {
      final notifications = ref.read(notificationControllerProvider);
      await ref
          .read(notificationControllerProvider.notifier)
          .apply(
            enabled: value.reminders,
            hour: notifications.hour,
            minute: notifications.minute,
            lastTraining: ref
                .read(notificationControllerProvider.notifier)
                .lastTraining,
            requestPermission: false,
          );
      if (mounted) setState(() => _profileSynced = true);
    }
  }

  Future<void> _toggleReminders(bool enabled) async {
    final result = await ref.read(profileProvider.future);
    if (!mounted || result is! Success<Usuario>) return;
    final user = result.value;
    final saved = await ref
        .read(profileRepositoryProvider)
        .save(user.copyWith(reminders: enabled));
    if (!mounted) return;
    if (saved case Failure<Usuario>(:final failure)) {
      _show(failure.message);
      return;
    }
    final notifications = ref.read(notificationControllerProvider);
    final scheduled = await ref
        .read(notificationControllerProvider.notifier)
        .apply(
          enabled: enabled,
          hour: notifications.hour,
          minute: notifications.minute,
          lastTraining: ref
              .read(notificationControllerProvider.notifier)
              .lastTraining,
        );
    if (!mounted) return;
    scheduled.fold(
      onFailure: (failure) => _show(failure.message),
      onSuccess: (_) => setState(() {}),
    );
    ref.invalidate(profileProvider);
  }

  Future<void> _pickReminderTime() async {
    final current = ref.read(notificationControllerProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null || !mounted) return;
    final result = await ref
        .read(notificationControllerProvider.notifier)
        .apply(
          enabled: current.enabled,
          hour: picked.hour,
          minute: picked.minute,
          lastTraining: ref
              .read(notificationControllerProvider.notifier)
              .lastTraining,
        );
    if (!mounted) return;
    result.fold(
      onFailure: (failure) => _show(failure.message),
      onSuccess: (_) => setState(() {}),
    );
  }

  Future<void> _exportData() async {
    setState(() => _busy = true);
    final service = await ref.read(dataPrivacyServiceProvider.future);
    final result =
        await service?.exportData() ??
        const Failure<Uint8List>(
          AppFailure(message: 'Entre para exportar seus dados.'),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result case Failure<Uint8List>(:final failure)) {
      _show(failure.message);
      return;
    }
    final bytes = (result as Success<Uint8List>).value;
    await SharePlus.instance.share(
      ShareParams(
        text: 'Meus dados do Vero',
        files: [
          XFile.fromData(
            bytes,
            name: 'vero-dados-pessoais.json',
            mimeType: 'application/json',
          ),
        ],
      ),
    );
  }

  Future<void> _deleteData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar meus dados?'),
        content: const Text(
          'O Vero vai apagar perfil, treinos, medidas, fotos, preferencias e backup desta conta. Essa acao nao pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar tudo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final service = await ref.read(dataPrivacyServiceProvider.future);
    final result =
        await service?.deleteEverything() ??
        const Failure<void>(
          AppFailure(message: 'Entre para apagar seus dados.'),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result case Failure<void>(:final failure)) {
      _show(failure.message);
      return;
    }
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.goNamed('login');
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openExternal(String value) async {
    final opened = await launchUrl(Uri.parse(value));
    if (!opened && mounted) _show('Nao foi possivel abrir este contato.');
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationControllerProvider);
    final lock = ref.watch(appLockProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade e configuracoes')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Seus dados',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Seus treinos, medidas e fotos ficam protegidos neste aparelho. O Vero so envia dados para a nuvem quando voce configura o backup Premium.',
            ),
            const SizedBox(height: 24),
            Text('Lembretes', style: Theme.of(context).textTheme.titleLarge),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lembrete de treino'),
              subtitle: const Text('Um lembrete tranquilo, sem cobranças.'),
              value: notifications.enabled,
              onChanged: _busy ? null : _toggleReminders,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: notifications.enabled && !_busy,
              title: const Text('Horario do lembrete'),
              subtitle: Text(notifications.timeLabel),
              trailing: const Icon(Icons.schedule_outlined),
              onTap: notifications.enabled && !_busy ? _pickReminderTime : null,
            ),
            const Divider(height: 40),
            Text('Protecao', style: Theme.of(context).textTheme.titleLarge),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bloqueio de tela'),
              subtitle: const Text('Use biometria ou a senha do aparelho.'),
              value: lock.enabled,
              onChanged: _busy
                  ? null
                  : (value) async {
                      final result = await ref
                          .read(appLockProvider.notifier)
                          .setEnabled(value);
                      if (!mounted) return;
                      if (result case Failure<void>(:final failure)) {
                        _show(failure.message);
                      }
                    },
            ),
            const Divider(height: 40),
            Text(
              'Controle dos dados',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Exportar meus dados'),
              subtitle: const Text(
                'Gera um arquivo JSON com seus dados e fotos.',
              ),
              onTap: _busy ? null : _exportData,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('Apagar meus dados'),
              subtitle: const Text(
                'Remove os dados deste aparelho e do backup.',
              ),
              onTap: _busy ? null : _deleteData,
            ),
            const Divider(height: 40),
            Text('Ajuda', style: Theme.of(context).textTheme.titleLarge),
            if (AppConfig.supportEmail.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline),
                title: const Text('Falar com o suporte'),
                subtitle: const Text(AppConfig.supportEmail),
                onTap: () => _openExternal(
                  'mailto:${Uri.encodeComponent(AppConfig.supportEmail)}',
                ),
              ),
            if (AppConfig.feedbackUrl.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('Enviar feedback'),
                onTap: () => _openExternal(AppConfig.feedbackUrl),
              ),
            if (AppConfig.supportEmail.isEmpty && AppConfig.feedbackUrl.isEmpty)
              const Text(
                'Configure VERO_SUPPORT_EMAIL ou VERO_FEEDBACK_URL no build de release.',
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.pushNamed('profile'),
              icon: const Icon(Icons.person_outline),
              label: const Text('Voltar ao perfil'),
            ),
          ],
        ),
      ),
    );
  }
}
