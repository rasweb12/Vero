import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vero/features/auth/data/secure_session_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'session persists securely, is project-scoped and is removed on logout',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      const storage = SecureSessionStorage('https://a.supabase.co');
      await storage.initialize();
      expect(await storage.hasAccessToken(), isFalse);
      await storage.persistSession('{"refresh_token":"test-only"}');
      const restored = SecureSessionStorage('https://a.supabase.co');
      expect(await restored.accessToken(), '{"refresh_token":"test-only"}');
      const otherProject = SecureSessionStorage('https://b.supabase.co');
      expect(await otherProject.accessToken(), isNull);
      await restored.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
    },
  );
}
