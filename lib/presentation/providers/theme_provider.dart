import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/models/theme_preference.dart';
import '../../domain/repositories/theme_repository.dart';
import '../../repositories/firestore_theme_repository.dart';
import 'sync_providers.dart';

final localThemeRepositoryProvider = Provider<LocalThemeRepository>((ref) {
  throw StateError('An initialized local theme repository is required.');
});

final remoteThemeRepositoryProvider = Provider<RemoteThemeRepository>((ref) {
  return FirestoreThemeRepository(FirebaseFirestore.instance);
});

final themeUserIdProvider = Provider<String?>((ref) {
  return ref
      .watch(authStateProvider)
      .when(
        data: (user) => user?.uid,
        loading: () => ref.watch(authServiceProvider).currentUser?.uid,
        error: (error, stackTrace) => null,
      );
});

final themeProvider = StateNotifierProvider<ThemeController, ThemeState>((ref) {
  return ThemeController(
    ref.watch(localThemeRepositoryProvider),
    ref.watch(remoteThemeRepositoryProvider),
    ref.watch(themeUserIdProvider),
  );
});

class ThemeState {
  const ThemeState(this.preference, {this.sync = const AsyncData<void>(null)});
  final ThemePreference preference;
  final AsyncValue<void> sync;
}

/// Keeps local writes responsive while remote requests run independently.
/// Each controller is bound to one account for its entire lifetime.
class ThemeController extends StateNotifier<ThemeState> {
  ThemeController(this._local, this._remote, this._userId)
    : super(ThemeState(_local.read(_userId) ?? const ThemePreference())) {
    unawaited(synchronize());
  }

  final LocalThemeRepository _local;
  final RemoteThemeRepository _remote;
  final String? _userId;
  Future<void> _localQueue = Future<void>.value();
  Future<void>? _syncFuture;
  bool _syncRequested = false;

  Future<void> _enqueueLocal(Future<void> Function() action) {
    final operation = _localQueue.then((_) async {
      if (mounted) await action();
    });
    _localQueue = operation.then<void>(
      (_) {},
      onError: (Object e, StackTrace s) {},
    );
    return operation;
  }

  Future<void> toggle() => _setTheme(null);
  Future<void> setTheme(AppTheme theme) => _setTheme(theme);

  Future<void> _setTheme(AppTheme? requested) async {
    try {
      await _enqueueLocal(() async {
        final current = state.preference;
        final theme =
            requested ??
            (current.theme == AppTheme.dark ? AppTheme.light : AppTheme.dark);
        final next = ThemePreference(
          theme: theme,
          updatedAt: max(
            DateTime.now().millisecondsSinceEpoch,
            current.updatedAt + 1,
          ),
          pending: true,
        );
        await _local.write(_userId, next);
        if (mounted) state = ThemeState(next, sync: state.sync);
      });
      if (mounted) await synchronize();
    } catch (error, stackTrace) {
      if (mounted) {
        state = ThemeState(
          state.preference,
          sync: AsyncError(error, stackTrace),
        );
      }
    }
  }

  /// Retries pending writes and retrieves changes on sign-in or app resume.
  /// Network errors leave the persisted local preference usable and pending.
  Future<void> synchronize() {
    if (!mounted || _userId == null) return Future<void>.value();
    _syncRequested = true;
    return _syncFuture ??= Future<void>.microtask(_synchronize)
        .whenComplete(() {
          _syncFuture = null;
        });
  }

  Future<void> _synchronize() async {
    try {
      do {
        _syncRequested = false;
        await _localQueue;
        if (!mounted) return;
        final snapshot = state.preference;
        state = ThemeState(snapshot, sync: const AsyncLoading<void>());
        final remote = await _remote.synchronize(
          _userId!,
          snapshot.pending ? snapshot : null,
        );
        await _enqueueLocal(() async {
          // A newer local toggle must never be replaced by a stale response.
          if (state.preference.updatedAt != snapshot.updatedAt) {
            _syncRequested = true;
            return;
          }
          if (remote != null) {
            final acknowledged = remote.acknowledged();
            await _local.write(_userId, acknowledged);
            if (mounted) state = ThemeState(acknowledged);
          } else {
            state = ThemeState(state.preference);
          }
        });
      } while (_syncRequested && mounted);
    } catch (error, stackTrace) {
      if (mounted) {
        state = ThemeState(
          state.preference,
          sync: AsyncError(error, stackTrace),
        );
      }
    }
  }
}
