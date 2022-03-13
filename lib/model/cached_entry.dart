import 'package:hive/hive.dart';

part 'cached_entry.g.dart';

@HiveType(typeId: 5)
class CachedEntry {
  @HiveField(1)
  final int revision;
  @HiveField(2)
  final String data;

  CachedEntry({
    required this.revision,
    required this.data,
  });
}
