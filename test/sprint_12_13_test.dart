import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vero/features/notifications/presentation/notification_controller.dart';
import 'package:vero/features/profile/domain/usuario.dart';
import 'package:vero/features/settings/presentation/security_provider.dart';

void main() {
  test('notification state formats the selected time', () {
    const state = NotificationState(hour: 7, minute: 5);

    expect(state.timeLabel, '07:05');
  });

  test('profile copyWith changes reminders without losing account data', () {
    const user = Usuario(
      id: 'user-a',
      email: 'ana@example.com',
      name: 'Ana',
      goalWeight: 64,
      weeklyGoal: 4,
      pendingUpload: true,
    );

    final updated = user.copyWith(reminders: true);

    expect(updated.id, user.id);
    expect(updated.email, user.email);
    expect(updated.goalWeight, user.goalWeight);
    expect(updated.weeklyGoal, user.weeklyGoal);
    expect(updated.reminders, isTrue);
    expect(updated.pendingUpload, isTrue);
  });

  test('app lock preference is disabled by default and persists off state', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AppLockController(preferences);
    await controller.ready;

    expect(controller.state.enabled, isFalse);
    final result = await controller.setEnabled(false);

    expect(result.isSuccess, isTrue);
    expect(preferences.getBool('security:app_lock_enabled'), isFalse);
  });
}
