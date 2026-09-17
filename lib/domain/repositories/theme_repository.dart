import '../models/theme_preference.dart';

abstract class LocalThemeRepository {
  ThemePreference? read(String? userId);
  Future<void> write(String? userId, ThemePreference preference);
}

abstract class RemoteThemeRepository {
  /// Atomically merges a pending local preference with the user's remote value.
  /// Remote wins timestamp ties; a null local value performs a server read only.
  Future<ThemePreference?> synchronize(String userId, ThemePreference? local);
}
