import 'package:isar/isar.dart';

part 'local_app_metadata.g.dart';

@collection
class LocalAppMetadata {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String key;

  late String value;

  DateTime updatedAt = DateTime.now();
}
