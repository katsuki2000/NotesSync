import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:notessync/application/services/notes_sync_service.dart';
import 'package:notessync/domain/services/note_conflict_resolver.dart';
import 'package:notessync/models/note.dart';

import '../../fakes/fake_local_repository.dart';
import '../../fakes/fake_remote_repository.dart';
import '../../fakes/note_fixture.dart';

void main() {
  late FakeLocalRepository local;
  late FakeRemoteRepository remote;
  late NotesSyncService service;

  setUp(() {
    local = FakeLocalRepository();
    remote = FakeRemoteRepository();
    service = NotesSyncService(
      localRepository: local,
      remoteRepository: remote,
    );
  });

  tearDown(() async {
    await local.dispose();
    await remote.dispose();
  });

  test('empty replicas remain empty', () async {
    expect(await service.synchronize(), isEmpty);
    expect(local.saveCount, 0);
    expect(remote.saveCount, 0);
  });

  test('copies notes in both directions without changing timestamps', () async {
    final localNote = makeNote(id: 'local');
    final remoteNote = makeNote(id: 'remote', revision: 1);
    await local.saveNote(localNote);
    await remote.saveNote(remoteNote);

    final result = await service.synchronize();
    final expected = [
      localNote.copyWith(isSynced: true),
      remoteNote.copyWith(isSynced: true),
    ];
    expect(result, expected);
    expect(await local.getNotes(), unorderedEquals(expected));
    expect(await remote.getNotes(), unorderedEquals(expected));
    expect(() => result.clear(), throwsUnsupportedError);
  });

  final base = makeNote(isSynced: true);
  final localEdit = makeNote(content: 'Local edit', revision: 1);
  final remoteEdit = makeNote(content: 'Remote edit', revision: 2);
  final scenarios = <(String, Note, Note, Note)>[
    ('local-only modification', localEdit, base, localEdit),
    ('remote-only modification', base, remoteEdit, remoteEdit),
    ('both modified, remote is newer', localEdit, remoteEdit, remoteEdit),
    (
      'both modified, local is newer',
      localEdit.copyWith(
        updatedAt: remoteEdit.updatedAt.add(const Duration(minutes: 1)),
      ),
      remoteEdit,
      localEdit.copyWith(
        updatedAt: remoteEdit.updatedAt.add(const Duration(minutes: 1)),
      ),
    ),
    (
      'equal timestamps with different content',
      localEdit.copyWith(updatedAt: remoteEdit.updatedAt),
      remoteEdit,
      remoteEdit,
    ),
    (
      'equal versions with different sync flags',
      base.copyWith(isSynced: false),
      base,
      base,
    ),
    (
      'newer remote wins even when local is marked dirty',
      localEdit,
      remoteEdit.copyWith(isSynced: true),
      remoteEdit,
    ),
  ];

  for (final (name, localVersion, remoteVersion, winner) in scenarios) {
    test(name, () async {
      await local.saveNote(base);
      await remote.saveNote(base);
      await service.synchronize();
      await local.saveNote(localVersion);
      await remote.saveNote(remoteVersion);

      final expected = winner.copyWith(isSynced: true);
      expect(await service.synchronize(), [expected]);
      expect(await local.getNoteById(base.id), expected);
      expect(await remote.getNoteById(base.id), expected);

      final writes = (local.saveCount, remote.saveCount);
      await service.synchronize();
      expect((local.saveCount, remote.saveCount), writes);
    });
  }

  test(
    'offline failure preserves local edits and a later retry succeeds',
    () async {
      final note = makeNote();
      await local.saveNote(note);
      remote.isOnline = false;

      await expectLater(service.synchronize(), throwsStateError);
      expect(await local.getNoteById(note.id), note);
      remote.isOnline = true;

      expect(await service.synchronize(), [note.copyWith(isSynced: true)]);
    },
  );

  test(
    'failed upload never acknowledges the local version as synced',
    () async {
      final note = makeNote();
      await local.saveNote(note);
      final failure = StateError('Upload failed');
      remote.nextWriteError = failure;

      await expectLater(service.synchronize(), throwsA(same(failure)));
      expect(await local.getNoteById(note.id), note);
      expect(await remote.getNotes(), isEmpty);
      expect(await service.synchronize(), [note.copyWith(isSynced: true)]);
    },
  );

  test(
    'retries a local failure after an upload without uploading again',
    () async {
      final note = makeNote();
      await local.saveNote(note);
      local.nextWriteError = StateError('Local disk failure');

      await expectLater(service.synchronize(), throwsStateError);
      expect(await local.getNoteById(note.id), note);
      expect(await remote.getNoteById(note.id), note.copyWith(isSynced: true));
      final uploads = remote.saveCount;

      expect(await service.synchronize(), [note.copyWith(isSynced: true)]);
      expect(remote.saveCount, uploads);
    },
  );

  test('serializes concurrent passes while an upload is pending', () async {
    final gatedRemote = GatedRemoteRepository();
    addTearDown(gatedRemote.dispose);
    final serialized = NotesSyncService(
      localRepository: local,
      remoteRepository: gatedRemote,
    );
    await local.saveNote(makeNote());
    final first = serialized.synchronize();
    await gatedRemote.started.future;
    final second = serialized.synchronize();
    await Future<void>.delayed(Duration.zero);
    expect(gatedRemote.readCount, 1);
    gatedRemote.release.complete();

    expect(await first, await second);
    expect(gatedRemote.saveCount, 1);
    expect(gatedRemote.readCount, 2);
  });

  test(
    'missing notes are restored because deletion tombstones are absent',
    () async {
      await local.saveNote(makeNote());
      await service.synchronize();
      await local.deleteNote('note-1');

      await service.synchronize();
      expect(await local.getNoteById('note-1'), makeNote(isSynced: true));
    },
  );

  test('resolver rejects different identifiers', () {
    expect(
      () => const NoteConflictResolver().resolve(
        local: makeNote(id: 'a'),
        remote: makeNote(id: 'b'),
      ),
      throwsArgumentError,
    );
  });

  test(
    'equivalent instants use the remote tie breaker regardless of offset',
    () {
      final localNote = makeNote().copyWith(
        updatedAt: DateTime.parse('2026-09-09T12:00:00+02:00'),
      );
      final remoteNote = makeNote(content: 'Remote content')
          .copyWith(updatedAt: DateTime.parse('2026-09-09T10:00:00Z'));
      expect(
        const NoteConflictResolver().resolve(
          local: localNote,
          remote: remoteNote,
        ),
        remoteNote,
      );
    },
  );
}

class GatedRemoteRepository extends FakeRemoteRepository {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> saveNote(Note note) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    await super.saveNote(note);
  }
}
