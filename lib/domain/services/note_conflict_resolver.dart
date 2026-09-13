import '../../models/note.dart';

/// Resolves competing versions using last-write-wins semantics.
class NoteConflictResolver {
  const NoteConflictResolver();

  /// Selects the latest timestamp, with the remote version winning ties.
  ///
  /// Synchronization metadata is not a version indicator. Comparing timestamps
  /// alone cannot establish whether both replicas changed since a common base.
  Note resolve({required Note local, required Note remote}) {
    if (local.id != remote.id) {
      throw ArgumentError('Cannot resolve notes with different identifiers.');
    }
    return local.updatedAt.isAfter(remote.updatedAt) ? local : remote;
  }
}
