import 'dart:async';

import 'package:notessync/domain/models/theme_preference.dart';
import 'package:notessync/domain/repositories/theme_repository.dart';

class FakeLocalThemeRepository implements LocalThemeRepository {
  final values = <String?, ThemePreference>{};
  bool failWrites = false;

  @override
  ThemePreference? read(String? userId) => values[userId];

  @override
  Future<void> write(String? userId, ThemePreference preference) async {
    if (failWrites) throw StateError('Local storage is unavailable.');
    values[userId] = preference;
  }
}

class FakeRemoteThemeRepository implements RemoteThemeRepository {
  final values = <String, ThemePreference>{};
  final requests = <String>[];
  bool offline = false;
  Completer<ThemePreference?>? nextResponse;

  @override
  Future<ThemePreference?> synchronize(
    String userId,
    ThemePreference? local,
  ) async {
    requests.add(userId);
    if (offline) throw StateError('Network is unavailable.');
    final response = nextResponse;
    if (response != null) {
      nextResponse = null;
      return response.future;
    }
    final remote = values[userId];
    if (local != null &&
        (remote == null || local.updatedAt > remote.updatedAt)) {
      values[userId] = local.acknowledged();
    }
    return values[userId];
  }
}
