# Notes synchronization (T-12 and T-13)

`NotesSyncService` merges complete local and remote snapshots. It depends only on
`NotesRepository` and `NoteConflictResolver`; Flutter and Riverpod stay in the
presentation layer. The service does not connect to Hive or Firestore directly.

| Local version | Remote version | Result |
| --- | --- | --- |
| Present | Missing | Upload the local note |
| Missing | Present | Download the remote note |
| Newer `updatedAt` | Older `updatedAt` | Local version wins |
| Older `updatedAt` | Newer `updatedAt` | Remote version wins |
| Equal timestamp | Equal timestamp | Remote version wins, including content ties |

The winning note is saved to both replicas with `isSynced: true`. Its original
timestamps, identifier, content, title, and tags are preserved. Remote writes
complete before the local synchronization flag is acknowledged. An unchanged
replica is not written again.

`isSynced` is metadata, not a conflict-resolution priority. Writers must update
`updatedAt` when editing and mark local edits as unsynchronized:

```dart
final edited = note.copyWith(
  content: newContent,
  updatedAt: DateTime.now().toUtc(),
  isSynced: false,
);
await ref.read(notesProvider.notifier).updateNote(edited);
```

## Riverpod integration

Provide initialized repositories at the application root. The existing
`notesRepositoryProvider` must resolve to local storage, so the list remains
available offline. `localNotesRepositoryProvider` delegates to it by default.
Do not override the local alias with a different repository from the notes list.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notessync/main.dart';
import 'package:notessync/presentation/providers/notes_provider.dart';
import 'package:notessync/presentation/providers/notes_sync_provider.dart';
import 'package:notessync/repositories/notes_repository.dart';

void runNotesApp({
  required NotesRepository localRepository,
  required NotesRepository remoteRepository,
}) {
  runApp(
    ProviderScope(
      overrides: [
        notesRepositoryProvider.overrideWithValue(localRepository),
        remoteNotesRepositoryProvider.overrideWithValue(remoteRepository),
      ],
      child: const MyApp(),
    ),
  );
}
```

In a `ConsumerWidget`, observe `ref.watch(notesSyncProvider)` and trigger a pass
with `await ref.read(notesSyncProvider.notifier).synchronize()`. The state is
`AsyncValue<void>`: initial data means idle, loading means an active pass, data
after a pass means success, and error contains the original synchronization
failure. The notifier refreshes `notesProvider` after success or partial failure;
local read failures appear separately in `notesProvider`.

Service calls throw on failure. Notifier calls publish errors in state instead
of throwing, so completing a widget callback's future does not imply success.
Passes on the same service instance are serialized, and a failed pass does not
block subsequent retries. Requests queued on a disposed notifier are skipped;
an already running service pass may finish without publishing presentation state.

## Fakes and verification

`test/fakes/fake_local_repository.dart` and
`test/fakes/fake_remote_repository.dart` implement the existing repository
contract using independent in-memory stores. Both support initial data, upserts,
lookups, deletes, immutable snapshots, and snapshot streams. Dispose them after
each test. Set `remote.isOnline = false` to simulate network failure or set
`nextWriteError` on either fake to fail its next write.

The fakes belong to tests and are not imported into production code. The tests
cover unilateral changes, simultaneous divergent edits, both timestamp orderings,
equal timestamps, metadata differences, retry after partial writes, overlapping
sync calls, Riverpod state transitions, and list refreshes.

```sh
flutter pub get
dart analyze .
flutter test
```

## Contract boundaries

- A missing note is copied from the other replica. Propagating deletions requires
  timestamped tombstones; deleting a note on one side alone will restore it.
- Last-write-wins chooses an entire note, not a field-by-field merge. Equal
  timestamps deterministically prefer remote content and may discard local edits.
- Timestamps must reflect comparable clocks. There is no common-base revision,
  so timestamps alone cannot distinguish a two-sided edit from a unilateral edit.
- Do not overlap external writes or editor saves with a synchronization pass.
  Serialization protects calls on this service instance only. Real multi-device
  concurrency needs transactional version checks in the repository contract.
- This is an explicit snapshot synchronization service. It does not subscribe to
  `watchNotes()`, schedule background work, or implement authentication.
