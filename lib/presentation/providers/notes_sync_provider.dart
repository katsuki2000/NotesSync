import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../application/services/notes_sync_service.dart';
import '../../repositories/firestore_notes_repository.dart';
import '../../repositories/notes_repository.dart';
import 'sync_providers.dart';
import 'notes_provider.dart';

/// Uses the same local repository as the notes presentation state.
final localNotesRepositoryProvider = Provider<NotesRepository>((ref) {
  return ref.watch(notesRepositoryProvider);
});

final remoteNotesRepositoryProvider = Provider<NotesRepository>((ref) {
  final user = ref.watch(authServiceProvider).currentUser;
  if (user == null) {
    throw StateError(
      'A signed-in user is required for Firestore synchronization.',
    );
  }
  return FirestoreNotesRepository(
    firestoreService: ref.watch(firestoreSyncServiceProvider),
    userId: user.uid,
  );
});

final notesSyncServiceProvider = Provider<NotesSyncService>((ref) {
  return NotesSyncService(
    localRepository: ref.watch(localNotesRepositoryProvider),
    remoteRepository: ref.watch(remoteNotesRepositoryProvider),
  );
});

/// Exposes idle/success, loading, and failure states for explicit sync requests.
final notesSyncProvider =
    StateNotifierProvider<NotesSyncNotifier, AsyncValue<void>>((ref) {
      return NotesSyncNotifier(
        ref.watch(notesSyncServiceProvider),
        () => ref.read(notesProvider.notifier).loadNotes(),
      );
    });

class NotesSyncNotifier extends StateNotifier<AsyncValue<void>> {
  NotesSyncNotifier(this._service, this._reloadNotes)
    : super(const AsyncData<void>(null));

  final NotesSyncService _service;
  final Future<void> Function() _reloadNotes;
  Future<void> _pending = Future<void>.value();

  /// Errors are exposed through state rather than rethrown to widget callbacks.
  Future<void> synchronize() {
    _pending = _pending.then((_) async {
      if (!mounted) return;
      state = const AsyncLoading<void>();
      final result = await AsyncValue.guard<void>(() async {
        try {
          await _service.synchronize();
        } finally {
          // Refresh partial progress after a failed pass as well as on success.
          if (mounted) await _reloadNotes();
        }
      });
      if (mounted) state = result;
    });
    return _pending;
  }
}
