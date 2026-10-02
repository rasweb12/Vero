import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/local_database_provider.dart';
import '../../../shared/utils/result.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_repository.dart';
import '../domain/usuario.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    ref.watch(localDatabaseProvider),
    ref.watch(supabaseClientProvider),
  ),
);

final profileProvider = FutureProvider.autoDispose<Result<Usuario>>((
  ref,
) async {
  final account = ref.watch(
    authControllerProvider.select((state) => state.account),
  );
  if (account == null) {
    return const Failure(AppFailure(message: 'Entre para ver seu perfil.'));
  }
  return ref.watch(profileRepositoryProvider).load(account);
});
