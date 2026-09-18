import 'package:flutter_test/flutter_test.dart';
import 'package:notessync/models/note.dart';

import 'fake_local_repository.dart';
import 'fake_remote_repository.dart';
import 'in_memory_notes_repository.dart';
import 'note_fixture.dart';

void main() {
  final factories = <String, InMemoryNotesRepository Function()>{
    'local': FakeLocalRepository.new,
    'remote': FakeRemoteRepository.new,
  };

  for (final entry in factories.entries) {
    test(
      '${entry.key} publishes initial, saved, and updated snapshots',
      () async {
        final repository = entry.value();
        addTearDown(repository.dispose);
        final note = makeNote();
        final updated = makeNote(content: 'Updated content', revision: 1);
        final observed = expectLater(
          repository.watchNotes(),
          emitsInOrder(<List<Note>>[
            [],
            [note],
            [updated],
          ]),
        );

        await repository.saveNote(note);
        await repository.saveNote(updated);
        expect(await repository.getNoteById(note.id), updated);
        await observed;
      },
    );

    test(
      '${entry.key} deleteNote writes a tombstone instead of removing the record',
      () async {
        final repository = entry.value();
        addTearDown(repository.dispose);
        final note = makeNote();

        await repository.saveNote(note);
        await repository.deleteNote(note.id);

        // Still retrievable at the repository level — it's the caller
        // (e.g. notesProvider) that hides tombstones from the UI, so
        // NotesSyncService can still see and propagate the deletion.
        final tombstone = await repository.getNoteById(note.id);
        expect(tombstone, isNotNull);
        expect(tombstone!.isDeleted, isTrue);
        expect(tombstone.deletedAt, isNotNull);
      },
    );

    test(
      '${entry.key} isolates stored notes from caller-owned tag lists',
      () async {
        final repository = entry.value();
        addTearDown(repository.dispose);
        final tags = ['original'];
        await repository.saveNote(makeNote().copyWith(tags: tags));
        tags.add('external change');

        final notes = await repository.getNotes();
        expect(notes.single.tags, ['original']);
        expect(() => notes.clear(), throwsUnsupportedError);
        expect(() => notes.single.tags.clear(), throwsUnsupportedError);
      },
    );
  }
}
