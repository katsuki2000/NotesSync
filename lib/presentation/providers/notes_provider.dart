import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../models/note.dart';
import '../../repositories/notes_repository.dart';

/// Override this provider with an initialized repository at the app root.
final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  throw StateError('A NotesRepository must be provided through ProviderScope.');
});

/// Exposes loading, data, and error states for the notes collection.
final notesProvider =
    StateNotifierProvider<NotesNotifier, AsyncValue<List<Note>>>((ref) {
      return NotesNotifier(ref.watch(notesRepositoryProvider));
    });

/// Coordinates persistence operations without depending on a storage backend.
class NotesNotifier extends StateNotifier<AsyncValue<List<Note>>> {
  NotesNotifier(this._repository) : super(const AsyncLoading<List<Note>>()) {
    unawaited(loadNotes());
  }

  final NotesRepository _repository;
  Future<void> _pending = Future<void>.value();

  /// Loads the latest repository snapshot, including synchronization metadata.
  Future<void> loadNotes() => _enqueue();

  /// Adds a note using the repository's upsert contract.
  Future<void> addNote(Note note) => _enqueue(() => _repository.saveNote(note));

  /// Updates a note using the repository's upsert contract.
  Future<void> updateNote(Note note) =>
      _enqueue(() => _repository.saveNote(note));

  /// Deletes a note by its identifier.
  Future<void> deleteNote(String id) =>
      _enqueue(() => _repository.deleteNote(id));

  /// Serializes requests so an older snapshot cannot overwrite a newer one.
  ///
  /// Failures are published as AsyncError rather than rethrown. Callers should
  /// observe notesProvider to determine whether an operation succeeded.
  /// Queued requests are skipped after disposal; active writes may still finish.
  Future<void> _enqueue([Future<void> Function()? mutation]) {
    _pending = _pending.then((_) async {
      if (!mounted) return;

      state = const AsyncLoading<List<Note>>();
      final result = await AsyncValue.guard<List<Note>>(() async {
        if (mutation != null) {
          await mutation();
        }
        final notes = await _repository.getNotes();
        // Les tombstones (deletedAt != null) restent en stockage pour que
        // NotesSyncService puisse propager la suppression à l'autre
        // replica, mais ne doivent jamais apparaître dans l'UI.
        return List<Note>.unmodifiable(notes.where((note) => !note.isDeleted));
      });

      if (mounted) {
        state = result;
      }
    });
    return _pending;
  }
}
