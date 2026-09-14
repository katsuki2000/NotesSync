import 'package:hive/hive.dart';

import '../domain/models/theme_preference.dart';
import '../domain/repositories/theme_repository.dart';

class HiveThemeRepository implements LocalThemeRepository {
  HiveThemeRepository(this._box);

  static const boxName = 'theme_preferences';
  final Box<Map<dynamic, dynamic>> _box;

  String _key(String? userId) => userId == null ? 'guest' : 'user:$userId';

  @override
  ThemePreference? read(String? userId) {
    final value = _box.get(_key(userId));
    return value == null ? null : ThemePreference.fromMap(value);
  }

  @override
  Future<void> write(String? userId, ThemePreference preference) =>
      _box.put(_key(userId), preference.toMap());
}
