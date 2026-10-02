import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';
import '../../../shared/utils/result.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/notification_service.dart';

class NotificationState {
  const NotificationState({
    this.ready = false,
    this.enabled = false,
    this.hour = 19,
    this.minute = 0,
    this.message,
  });

  final bool ready;
  final bool enabled;
  final int hour;
  final int minute;
  final String? message;

  NotificationState copyWith({
    bool? ready,
    bool? enabled,
    int? hour,
    int? minute,
    String? message,
    bool clearMessage = false,
  }) => NotificationState(
    ready: ready ?? this.ready,
    enabled: enabled ?? this.enabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    message: clearMessage ? null : message ?? this.message,
  );

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final notificationControllerProvider =
    StateNotifierProvider.autoDispose<
      NotificationController,
      NotificationState
    >((ref) {
      final accountId = ref.watch(
        authControllerProvider.select((state) => state.account?.id),
      );
      return NotificationController(
        ref.watch(notificationServiceProvider),
        ref.watch(sharedPreferencesProvider),
        accountId,
      );
    });

class NotificationController extends StateNotifier<NotificationState> {
  NotificationController(this.service, this.preferences, this.ownerId)
    : super(const NotificationState()) {
    ready = _load();
  }

  final NotificationService service;
  final SharedPreferences preferences;
  final String? ownerId;
  late final Future<void> ready;

  String get _prefix => 'notifications:${ownerId ?? 'signed-out'}';

  Future<void> _load() async {
    if (ownerId == null) {
      state = state.copyWith(ready: true);
      return;
    }
    try {
      await service.initialize();
      state = state.copyWith(
        ready: true,
        enabled: preferences.getBool('$_prefix:enabled') ?? false,
        hour: preferences.getInt('$_prefix:hour') ?? 19,
        minute: preferences.getInt('$_prefix:minute') ?? 0,
      );
    } on Exception {
      state = state.copyWith(
        ready: true,
        message: 'Notificacoes indisponiveis neste dispositivo.',
      );
    }
  }

  Future<Result<void>> apply({
    required bool enabled,
    required int hour,
    required int minute,
    DateTime? lastTraining,
    bool requestPermission = true,
  }) async {
    await ready;
    if (ownerId == null) {
      return const Failure(
        AppFailure(message: 'Entre para configurar lembretes.'),
      );
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return const Failure(AppFailure(message: 'Escolha um horario valido.'));
    }
    try {
      if (enabled && requestPermission && !await service.requestPermission()) {
        return const Failure(
          AppFailure(message: 'Permissao de notificacoes nao concedida.'),
        );
      }
      if (enabled) {
        await service.schedule(
          hour: hour,
          minute: minute,
          lastTraining: lastTraining,
        );
      } else {
        await service.cancelAll();
      }
      await preferences.setBool('$_prefix:enabled', enabled);
      await preferences.setInt('$_prefix:hour', hour);
      await preferences.setInt('$_prefix:minute', minute);
      state = NotificationState(
        ready: true,
        enabled: enabled,
        hour: hour,
        minute: minute,
      );
      return const Success(null);
    } on Exception {
      return const Failure(
        AppFailure(message: 'Nao foi possivel atualizar os lembretes.'),
      );
    }
  }

  Future<void> recordTrainingFinished(DateTime date) async {
    await ready;
    if (ownerId == null) return;
    await preferences.setString(
      '$_prefix:last_training',
      date.toIso8601String(),
    );
    if (!state.enabled) return;
    await service.schedule(
      hour: state.hour,
      minute: state.minute,
      lastTraining: date,
    );
  }

  DateTime? get lastTraining {
    final value = preferences.getString('$_prefix:last_training');
    return value == null ? null : DateTime.tryParse(value);
  }
}
