import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notessync/presentation/providers/notes_provider.dart';
import 'package:notessync/presentation/providers/notes_sync_provider.dart';

import '../../fakes/fake_local_repository.dart';
import '../../fakes/fake_remote_repository.dart';
import '../../fakes/note_fixture.dart';

void main() {
  late FakeLocalRepository local;
  late FakeRemoteRepository remote;
  late ProviderContainer container;

  setUp(() {
    local = FakeLocalRepository();
    remote = FakeRemoteRepository();
    container = ProviderContainer(
      overrides: [
        notesRepositoryProvider.overrideWithValue(local),
        remoteNotesRepositoryProvider.overrideWithValue(remote),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await local.dispose();
    await remote.dispose();
  });

  test(
    'publishes loading and success, then refreshes the notes provider',
    () async {
      final note = makeNote(content: 'Remote edit', revision: 1);
      await remote.saveNote(note);
      final states = <AsyncValue<void>>[];
      container.listen(notesSyncProvider, (_, next) => states.add(next));

      await container.read(notesSyncProvider.notifier).synchronize();

      expect(states.first.isLoading, isTrue);
      expect(states.last, isA<AsyncData<void>>());
      expect(container.read(notesProvider).requireValue, [
        note.copyWith(isSynced: true),
      ]);
      expect(await local.getNotes(), await remote.getNotes());
    },
  );

  test(
    'publishes offline errors, preserves local data, and supports retry',
    () async {
      final note = makeNote();
      await local.saveNote(note);
      remote.isOnline = false;
      final notifier = container.read(notesSyncProvider.notifier);

      await notifier.synchronize();
      expect(container.read(notesSyncProvider).error, isA<StateError>());
      expect(container.read(notesProvider).requireValue, [note]);

      remote.isOnline = true;
      await notifier.synchronize();
      expect(container.read(notesSyncProvider), isA<AsyncData<void>>());
      expect(container.read(notesProvider).requireValue, [
        note.copyWith(isSynced: true),
      ]);
    },
  );

  test('ignores requests on a disposed notifier', () async {
    final notifier = NotesSyncNotifier(
      container.read(notesSyncServiceProvider),
      () async => fail('Disposed notifier must not reload notes.'),
    );
    notifier.dispose();
    await notifier.synchronize();
    expect(local.readCount, 0);
    expect(remote.readCount, 0);
  });
}
