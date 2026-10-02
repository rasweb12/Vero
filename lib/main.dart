import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'features/auth/data/secure_session_storage.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'shared/config/app_config.dart';
import 'shared/database/isar_database.dart';
import 'shared/providers/local_database_provider.dart';
import 'shared/providers/shared_preferences_provider.dart';
import 'shared/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final sharedPreferences = await SharedPreferences.getInstance();
    final localDatabase = await IsarDatabase.open();
    SupabaseClient? supabaseClient;
    if (AppConfig.hasSupabaseCredentials) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          localStorage: SecureSessionStorage(AppConfig.supabaseUrl),
          detectSessionInUri: false,
        ),
      );
      supabaseClient = Supabase.instance.client;
    }

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          localDatabaseProvider.overrideWithValue(localDatabase),
          supabaseClientProvider.overrideWithValue(supabaseClient),
        ],
        child: const VeroApp(),
      ),
    );
  } catch (_) {
    // Do not log keys or native exception details that may contain user data.
    runApp(const _StartupFailureApp());
  }
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 40),
                  SizedBox(height: 16),
                  Text(
                    'Nao foi possivel abrir seus dados com seguranca. '
                    'Feche e abra o Vero para tentar novamente.',
                    textAlign: TextAlign.center,
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
