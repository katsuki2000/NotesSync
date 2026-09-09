import '../../domain/services/note_conflict_resolver.dart';
import '../../models/note.dart';
import '../../repositories/notes_repository.dart';

/// Merges local and remote snapshots without depending on Flutter or Riverpod.
///
/// Missing notes are copied, not treated as deletions: the repository contract
/// has no tombstones. External edits must not overlap a synchronization pass;
/// atomic compare-and-set writes require a stronger repository contract.
class NotesSyncService {
  NotesSyncService({
    required NotesRepository localRepository,
    required NotesRepository remoteRepository,
    NoteConflictResolver conflictResolver = const NoteConflictResolver(),
  }) : _local = localRepository,
       _remote = remoteRepository,
       _resolver = conflictResolver;

  final NotesRepository _local;
  final NotesRepository _remote;
  final NoteConflictResolver _resolver;
  Future<void> _pending = Future<void>.value();

  /// Runs synchronization passes in order and propagates failures to callers.
  ///
  /// Successful writes remain persisted if a later operation fails. Repeating
  /// the pass converges both replicas without changing their version timestamps.
  Future<List<Note>> synchronize() {
    final operation = _pending.then((_) => _synchronize());
    _pending = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }

  Future<List<Note>> _synchronize() async {
    final localNotes = _index(await _local.getNotes());
    final remoteNotes = _index(await _remote.getNotes());
    final identifiers = {...localNotes.keys, ...remoteNotes.keys}.toList()
      ..sort();
    final synchronized = <Note>[];

    for (final id in identifiers) {
      final local = localNotes[id];
      final remote = remoteNotes[id];
      final Note winner;
      if (local == null) {
        winner = remote!;
      } else if (remote == null) {
        winner = local;
      } else {
        winner = _resolver.resolve(local: local, remote: remote);
      }

      final resolved = winner.copyWith(
        tags: List<String>.unmodifiable(winner.tags),
        isSynced: true,
      );

      // Persist remotely before acknowledging synchronization in local storage.
      if (remote != resolved) await _remote.saveNote(resolved);
      if (local != resolved) await _local.saveNote(resolved);
      synchronized.add(resolved);
    }

    return List<Note>.unmodifiable(synchronized);
  }

  Map<String, Note> _index(List<Note> notes) {
    final indexed = <String, Note>{};
    for (final note in notes) {
      if (indexed.containsKey(note.id)) {
        throw StateError('Duplicate note identifier: ${note.id}');
      }
      indexed[note.id] = note.copyWith(
        tags: List<String>.unmodifiable(note.tags),
      );
    }
    return indexed;
  }
}
