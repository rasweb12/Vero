import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vero/app.dart';
import 'package:vero/features/auth/presentation/auth_controller.dart';
import 'package:vero/features/measurements/domain/measurement_models.dart';
import 'package:vero/features/profile/domain/usuario.dart';
import 'package:vero/features/profile/presentation/profile_providers.dart';
import 'package:vero/features/subscription/domain/app_plan.dart';
import 'package:vero/features/subscription/presentation/plan_provider.dart';
import 'package:vero/features/training/domain/training_models.dart';
import 'package:vero/shared/providers/clock_provider.dart';
import 'package:vero/shared/providers/local_database_provider.dart';
import 'package:vero/shared/providers/router_provider.dart';
import 'package:vero/shared/providers/shared_preferences_provider.dart';
import 'package:vero/shared/utils/result.dart';

import 'profile_plan_test.dart' show MemoryDatabase;
import 'support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/fonts/Inter.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final preview in [
    (name: 'login_phone', path: '/login', width: 390.0, dark: false),
    (name: 'profile_dark', path: '/profile', width: 390.0, dark: true),
    (
      name: 'active_narrow',
      path: '/training/active',
      width: 320.0,
      dark: false,
    ),
    (name: 'plans_wide', path: '/plans', width: 900.0, dark: false),
    (
      name: 'measurements_narrow',
      path: '/measurements',
      width: 320.0,
      dark: false,
    ),
    (name: 'progress_phone', path: '/progress', width: 390.0, dark: false),
  ]) {
    testWidgets('preview ${preview.name}', (tester) async {
      tester.view.physicalSize = Size(preview.width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'theme_mode': preview.dark ? 'dark' : 'light',
      });
      final auth = FakeAuthRepository();
      if (preview.path != '/login') {
        auth.currentAccount = FakeAuthRepository.account;
      }
      final database = MemoryDatabase();
      database.values['measurements:user-a'] = jsonEncode(
        MeasurementData(
          records: [
            for (var i = 0; i < 8; i++)
              RegistroMedida(
                id: '$i',
                date: DateTime(2026, 9, 1 + i * 2),
                weight: 74 - i * 0.2,
                circumferences: {BodyMetric.waist: 82 - i * 0.1},
              ),
          ],
        ).toJson(),
      );
      final routine = Treino(
        id: 'a',
        name: 'Peito e ombros',
        exercises: [
          ExercicioTreino(
            exerciseId: 'bench-press',
            sets: const [Serie(weight: 25), Serie(weight: 25)],
          ),
        ],
      );
      database.values['training:user-a'] = jsonEncode(
        TrainingData(
          routines: [routine],
          active: TrainingSession(
            id: 'active',
            routine: routine,
            startedAt: DateTime.now(),
          ),
        ).toJson(),
      );
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(() => DateTime(2026, 9, 23)),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          authRepositoryProvider.overrideWithValue(auth),
          localDatabaseProvider.overrideWithValue(database),
          profileProvider.overrideWith(
            (ref) async => const Success(
              Usuario(
                id: 'user-a',
                name: 'Ana',
                email: 'ana@example.com',
                goalWeight: 68,
              ),
            ),
          ),
          planProvider.overrideWith((ref) async => const Success(AppPlan.free)),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const RepaintBoundary(
            key: ValueKey('preview'),
            child: VeroApp(),
          ),
        ),
      );
      container.read(routerProvider).go(preview.path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('preview')),
        matchesGoldenFile('goldens/${preview.name}.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await auth.changes.close();
    });
  }
}
