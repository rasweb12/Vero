import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/database/local_database.dart';
import '../../../shared/utils/result.dart';
import '../../auth/domain/auth_repository.dart';
import '../domain/usuario.dart';

class ProfileRepository {
  const ProfileRepository(this.database, this.client);
  final LocalDatabase database;
  final SupabaseClient? client;

  Future<Result<Usuario>> load(Account account) async {
    final cached = await database.read('profile:${account.id}');
    if (cached case Failure<String?>(:final failure)) return Failure(failure);
    final value = (cached as Success<String?>).value;
    try {
      if (value != null) {
        final user = Usuario.fromJson(
          jsonDecode(value) as Map<String, dynamic>,
          email: account.email,
        );
        if (user.id != account.id) {
          return const Failure(AppFailure(message: 'Perfil local invalido.'));
        }
        return Success(user);
      }
      final row = await client
          ?.from('profiles')
          .select()
          .eq('id', account.id)
          .maybeSingle();
      final user = row == null
          ? Usuario(id: account.id, email: account.email, name: account.name)
          : Usuario.fromJson(row, email: account.email);
      final saved = await database.write(
        'profile:${account.id}',
        jsonEncode(user.toLocalJson()),
      );
      if (saved case Failure<void>(:final failure)) return Failure(failure);
      return Success(user);
    } on FormatException {
      return const Failure(
        AppFailure(message: 'Nao foi possivel ler o perfil local.'),
      );
    } on Exception {
      // Do not overwrite an unavailable remote profile with empty defaults.
      return const Failure(
        AppFailure(
          message: 'Conecte-se para carregar seu perfil pela primeira vez.',
        ),
      );
    }
  }

  Future<Result<Usuario>> save(Usuario user) async {
    if (client?.auth.currentUser?.id != user.id) {
      return const Failure(
        AppFailure(message: 'Entre novamente para salvar seu perfil.'),
      );
    }
    if (user.name.trim().isEmpty ||
        user.name.length > 80 ||
        user.weeklyGoal < 1 ||
        user.weeklyGoal > 7 ||
        (user.goalWeight != null &&
            (!user.goalWeight!.isFinite ||
                user.goalWeight! < 20 ||
                user.goalWeight! > 500))) {
      return const Failure(AppFailure(message: 'Confira os dados do perfil.'));
    }
    final pending = user.withPendingUpload(true);
    final local = await database.write(
      'profile:${user.id}',
      jsonEncode(pending.toLocalJson()),
    );
    if (local case Failure<void>(:final failure)) return Failure(failure);
    try {
      await client!.from('profiles').upsert(user.toRemoteJson());
      final synced = user.withPendingUpload(false);
      final saved = await database.write(
        'profile:${user.id}',
        jsonEncode(synced.toLocalJson()),
      );
      return Success(saved.isSuccess ? synced : pending);
    } on Exception {
      return Success(pending);
    }
  }
}
