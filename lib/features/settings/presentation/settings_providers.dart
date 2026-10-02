import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/local_database_provider.dart';
import '../../../shared/providers/shared_preferences_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/presentation/notification_controller.dart';
import '../../photos/presentation/photo_controller.dart';
import '../data/data_privacy_service.dart';

final dataPrivacyServiceProvider =
    FutureProvider.autoDispose<DataPrivacyService?>((ref) async {
      final account = ref.watch(authControllerProvider).account;
      if (account == null) return null;
      return DataPrivacyService(
        database: ref.watch(localDatabaseProvider),
        files: await ref.watch(photoStoreProvider.future),
        preferences: ref.watch(sharedPreferencesProvider),
        ownerId: account.id,
        client: ref.watch(supabaseClientProvider),
        notifications: ref.watch(notificationServiceProvider),
      );
    });
