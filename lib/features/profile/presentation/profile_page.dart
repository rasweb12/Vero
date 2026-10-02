import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/theme_mode_provider.dart';
import '../../../shared/utils/result.dart';
import '../../../shared/widgets/vero_text_field.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/presentation/notification_controller.dart';
import '../../subscription/presentation/plan_provider.dart';
import '../../sync/domain/sync_models.dart';
import '../../sync/presentation/sync_controller.dart';
import '../../training/presentation/training_controller.dart';
import '../domain/usuario.dart';
import 'profile_providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    final result = await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    setState(() => _loggingOut = false);
    if (result case Failure<void>(:final failure)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vero'),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: _loggingOut ? null : _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, trace) => _retry('Nao foi possivel carregar seu perfil.'),
          data: (result) => result.fold(
            onFailure: (failure) => _retry(failure.message),
            onSuccess: (user) =>
                _ProfileForm(key: ValueKey(user.id), user: user),
          ),
        ),
      ),
    );
  }

  Widget _retry(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(profileProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.user, super.key});
  final Usuario user;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _weight;
  late int _weeklyGoal;
  late bool _reminders;
  late bool _pending;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name);
    _weight = TextEditingController(
      text: widget.user.goalWeight?.toString().replaceAll('.', ',') ?? '',
    );
    _weeklyGoal = widget.user.weeklyGoal;
    _reminders = widget.user.reminders;
    _pending = widget.user.pendingUpload;
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    super.dispose();
  }

  double? _parseWeight(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final result = await ref
        .read(profileRepositoryProvider)
        .save(
          Usuario(
            id: widget.user.id,
            email: widget.user.email,
            name: _name.text.trim(),
            goalWeight: _parseWeight(_weight.text),
            weeklyGoal: _weeklyGoal,
            reminders: _reminders,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    final message = result.fold(
      onFailure: (failure) => failure.message,
      onSuccess: (user) {
        setState(() => _pending = user.pendingUpload);
        final history = ref
            .read(trainingControllerProvider)
            .asData
            ?.value
            .history
            .where((session) => session.finishedAt != null)
            .map((session) => session.finishedAt!)
            .toList();
        history?.sort();
        final notification = ref.read(notificationControllerProvider);
        unawaited(
          ref
              .read(notificationControllerProvider.notifier)
              .apply(
                enabled: user.reminders,
                hour: notification.hour,
                minute: notification.minute,
                lastTraining: history?.lastOrNull,
              ),
        );
        return user.pendingUpload
            ? 'Salvo neste aparelho. Toque em salvar quando estiver conectado para enviar a nuvem.'
            : 'Perfil salvo.';
      },
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    if (result.isSuccess) ref.invalidate(profileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeModeProvider);
    final plan = ref.watch(effectivePlanProvider);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Meu perfil',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(widget.user.email),
              const SizedBox(height: 24),
              VeroTextField(
                labelText: 'Nome',
                controller: _name,
                enabled: !_saving,
                autofillHints: const [AutofillHints.name],
                validator: (value) =>
                    value == null ||
                        value.trim().isEmpty ||
                        value.trim().length > 80
                    ? 'Informe um nome de ate 80 caracteres.'
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                'Minhas metas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              VeroTextField(
                labelText: 'Meta de peso (kg, opcional)',
                controller: _weight,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final weight = _parseWeight(value);
                  return weight == null ||
                          !weight.isFinite ||
                          weight < 20 ||
                          weight > 500
                      ? 'Informe um valor entre 20 e 500 kg.'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Text('Treinos por semana')),
                  IconButton(
                    tooltip: 'Diminuir meta semanal',
                    onPressed: _saving || _weeklyGoal <= 1
                        ? null
                        : () => setState(() => _weeklyGoal--),
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 24,
                    child: Text('$_weeklyGoal', textAlign: TextAlign.center),
                  ),
                  IconButton(
                    tooltip: 'Aumentar meta semanal',
                    onPressed: _saving || _weeklyGoal >= 7
                        ? null
                        : () => setState(() => _weeklyGoal++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const Divider(height: 40),
              Text(
                'Preferencias',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Receber lembretes'),
                subtitle: const Text(
                  'Um lembrete tranquilo no horario que voce escolher.',
                ),
                value: _reminders,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _reminders = value),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ThemeMode>(
                initialValue: theme,
                decoration: const InputDecoration(labelText: 'Aparencia'),
                items: const [
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('Sistema'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.light,
                    child: Text('Claro'),
                  ),
                  DropdownMenuItem(
                    value: ThemeMode.dark,
                    child: Text('Escuro'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(value);
                  }
                },
              ),
              const SizedBox(height: 24),
              if (_pending)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Alteracoes salvas neste aparelho; envio pendente.',
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Salvando...' : 'Salvar perfil'),
              ),
              const Divider(height: 40),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Meu plano'),
                subtitle: Text('${plan.label} - selecao local'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('plans'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Privacidade e configuracoes'),
                subtitle: const Text('Lembretes, bloqueio e seus dados'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.pushNamed('settings'),
              ),
              const Divider(height: 40),
              _SyncTile(
                state: ref.watch(syncControllerProvider),
                onPressed: () async {
                  await ref.read(syncControllerProvider.notifier).syncNow();
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncTile extends StatelessWidget {
  const _SyncTile({required this.state, required this.onPressed});
  final SyncState state;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (state.status) {
      SyncStatus.syncing => (Icons.sync, 'Sincronizando...'),
      SyncStatus.synced => (Icons.cloud_done_outlined, 'Sincronizado'),
      SyncStatus.offline => (
        Icons.cloud_off_outlined,
        'Somente neste aparelho',
      ),
      SyncStatus.requiresPlan => (Icons.lock_outline, 'Backup Premium'),
      SyncStatus.error => (Icons.error_outline, 'Sincronizacao pendente'),
      SyncStatus.idle => (Icons.cloud_upload_outlined, 'Sincronizar dados'),
    };
    final pending = state.pending == 0
        ? ''
        : ' (${state.pending} pendente${state.pending == 1 ? '' : 's'})';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text('$label$pending'),
      subtitle: Text(
        state.message ??
            'Treinos, medidas e fotos cifrados ficam na fila quando voce estiver offline.',
      ),
      trailing: IconButton(
        tooltip: 'Sincronizar agora',
        onPressed: state.status == SyncStatus.syncing ? null : onPressed,
        icon: const Icon(Icons.refresh),
      ),
    );
  }
}
