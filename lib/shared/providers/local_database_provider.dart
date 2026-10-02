import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/local_database.dart';

final localDatabaseProvider = Provider<LocalDatabase>(
  (ref) => throw UnimplementedError(
    'localDatabaseProvider must be overridden during app bootstrap.',
  ),
);
