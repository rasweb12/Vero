import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vero/app.dart';
import 'package:vero/features/auth/presentation/auth_controller.dart';
import 'package:vero/features/profile/domain/usuario.dart';
import 'package:vero/features/profile/presentation/profile_providers.dart';
import 'package:vero/features/subscription/domain/app_plan.dart';
import 'package:vero/features/subscription/presentation/plan_provider.dart';
import 'package:vero/shared/providers/local_database_provider.dart';
import 'package:vero/shared/providers/shared_preferences_provider.dart';
import 'package:vero/shared/utils/result.dart';

import 'profile_plan_test.dart' show MemoryDatabase;
import 'support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAuthRepository auth;

  setUp(() {
    auth = FakeAuthRepository();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async => auth.changes.close());

  Future<void> mount(WidgetTester tester, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authRepositoryProvider.overrideWithValue(auth),
          localDatabaseProvider.overrideWithValue(MemoryDatabase()),
          profileProvider.overrideWith(
            (ref) async => const Success(
              Usuario(id: 'user-a', email: 'ana@example.com', name: 'Ana'),
            ),
          ),
          planProvider.overrideWith((ref) async => const Success(AppPlan.free)),
        ],
        child: const VeroApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('login validates fields before calling backend', (tester) async {
    await mount(tester);
    expect(find.text('Seu ritmo. Seus resultados.'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um e-mail valido.'), findsOneWidget);
    expect(auth.loginCalls, 0);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'ana@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'password123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Meu perfil'), findsOneWidget);
    await tester.tap(find.byTooltip('Sair da conta'));
    await tester.pumpAndSettle();
    expect(find.text('Meu perfil'), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
  });

  testWidgets(
    'registration requires matching password then email confirmation',
    (tester) async {
      await mount(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Criar conta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Ana');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail'),
        'ana@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar senha'),
        'different',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar conta'));
      await tester.pumpAndSettle();
      expect(find.text('As senhas precisam ser iguais.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar senha'),
        'password123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar conta'));
      await tester.pumpAndSettle();
      expect(find.text('Codigo do e-mail'), findsOneWidget);
    },
  );

  testWidgets('recovery requires code before setting new password', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail'),
      'ana@example.com',
    );
    await tester.tap(find.text('Enviar codigo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Codigo do e-mail'),
      '123456',
    );
    await tester.tap(find.text('Confirmar codigo'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, 'Nova senha'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha'),
      'newpassword123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar senha'),
      'newpassword123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Nova senha'));
    await tester.pumpAndSettle();
    expect(find.text('Sua semana'), findsOneWidget);
  });

  testWidgets('profile and plans fit narrow screen; theme persists', (
    tester,
  ) async {
    auth.currentAccount = FakeAuthRepository.account;
    await mount(tester, width: 320);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    final listScroll = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Aparencia'),
      160,
      scrollable: listScroll,
    );
    await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro').last);
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString('theme_mode'),
      'dark',
    );
    await tester.scrollUntilVisible(
      find.text('Meu plano'),
      120,
      scrollable: listScroll,
    );
    await tester.tap(find.text('Meu plano'));
    await tester.pumpAndSettle();
    expect(find.text('No seu ritmo'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Premium anual'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unconfigured build keeps authentication actions user-facing', (
    tester,
  ) async {
    auth.configured = false;
    await mount(tester);
    expect(
      tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Entrar'))
          .onPressed,
      isNotNull,
    );
    expect(
      find.text(
        'Configure SUPABASE_URL e SUPABASE_ANON_KEY para ativar sua conta.',
      ),
      findsNothing,
    );
  });

  testWidgets('records measurements with decimal comma and opens progress', (
    tester,
  ) async {
    auth.currentAccount = FakeAuthRepository.account;
    await mount(tester, width: 320);
    await tester.tap(find.text('Medidas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Registrar medidas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Peso'), '72,5');
    await tester.enterText(find.widgetWithText(TextFormField, 'Cintura'), '80');
    await tester.ensureVisible(find.text('Salvar registro'));
    await tester.tap(find.text('Salvar registro'));
    await tester.pumpAndSettle();
    expect(find.text('72,5 kg'), findsOneWidget);
    await tester.tap(find.text('Evolucao'));
    await tester.pumpAndSettle();
    expect(find.text('3 meses'), findsOneWidget);
    expect(find.text('Todo o historico'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create routine, train offline and review saved history', (
    tester,
  ) async {
    auth.currentAccount = FakeAuthRepository.account;
    await mount(tester, width: 320);
    await tester.tap(find.text('Criar rotina'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome do treino'),
      'Treino A',
    );
    await tester.tap(find.text('Adicionar exercicio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supino reto'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('bench-press-0-weight')),
      '25',
    );
    await tester.ensureVisible(find.byTooltip('Adicionar serie'));
    await tester.tap(find.byTooltip('Adicionar serie'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Salvar treino'));
    await tester.pumpAndSettle();
    expect(find.text('Treino A'), findsOneWidget);
    await tester.tap(find.text('Iniciar treino'));
    await tester.pumpAndSettle();
    expect(find.text('25'), findsOneWidget);
    await tester.tap(find.byTooltip('Aumentar Kg').first);
    await tester.pumpAndSettle();
    expect(find.text('27,5'), findsOneWidget);
    await tester.tap(find.text('Concluir serie').first);
    await tester.pumpAndSettle();
    expect(find.text('Repouso'), findsOneWidget);
    await tester.tap(find.byTooltip('Voltar e manter treino'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Treino em andamento'));
    await tester.pumpAndSettle();
    expect(find.text('Concluida'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Finalizar treino'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Finalizar treino'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(find.text('Treino concluido'), findsOneWidget);
    expect(find.text('Serie 1: 10 reps · 27,5 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
