import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notessync/models/note.dart';
import 'package:notessync/presentation/providers/notes_provider.dart';
import 'package:notessync/repositories/notes_repository.dart';

void main() {
  late FakeNotesRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeNotesRepository();
    container = ProviderContainer(
      overrides: [notesRepositoryProvider.overrideWithValue(repository)],
    );
  });

  tearDown(() => container.dispose());

  test('loads notes automatically through the injected repository', () async {
    repository.notes = [createNote()];
    final loaded = Completer<void>();
    container.listen(notesProvider, (_, next) {
      if (next.hasValue && !loaded.isCompleted) loaded.complete();
    });

    expect(container.read(notesProvider).isLoading, isTrue);
    await loaded.future;
    expect(container.read(notesProvider).requireValue, repository.notes);
    expect(repository.readCount, 1);
  });

  test('serializes writes and reloads authoritative repository data', () async {
    final notifier = container.read(notesProvider.notifier);
    final note = createNote();
    final updated = note.copyWith(title: 'Updated title');

    await Future.wait([notifier.addNote(note), notifier.updateNote(updated)]);
    expect(container.read(notesProvider).requireValue, [updated]);
    expect(repository.readCount, 3);

    await notifier.deleteNote(note.id);
    expect(container.read(notesProvider).requireValue, isEmpty);
  });

  test('exposes read errors and recovers on reload', () async {
    final failure = StateError('Read failed');
    repository.failure = failure;
    final notifier = container.read(notesProvider.notifier);

    await notifier.loadNotes();
    expect(container.read(notesProvider).error, same(failure));
    expect(container.read(notesProvider).stackTrace, isNotNull);

    repository.failure = null;
    await notifier.loadNotes();
    expect(container.read(notesProvider).requireValue, isEmpty);
  });

  test('publishes write errors without blocking subsequent requests', () async {
    final notifier = container.read(notesProvider.notifier);
    await notifier.loadNotes();
    final failure = StateError('Write failed');
    repository.failure = failure;

    await notifier.addNote(createNote());
    expect(container.read(notesProvider).error, same(failure));
    await notifier.updateNote(createNote());
    expect(container.read(notesProvider).error, same(failure));
    await notifier.deleteNote('note-1');
    expect(container.read(notesProvider).error, same(failure));

    repository.failure = null;
    await notifier.addNote(createNote());
    expect(container.read(notesProvider).requireValue, [createNote()]);
  });

  test(
    'does not publish results or execute queued writes after disposal',
    () async {
      final gate = Completer<List<Note>>();
      repository.readGate = gate;
      final notifier = NotesNotifier(repository);
      await Future<void>.delayed(Duration.zero);
      final pending = notifier.addNote(createNote());

      notifier.dispose();
      gate.complete([]);
      await pending;

      expect(repository.notes, isEmpty);
      expect(repository.readCount, 1);
    },
  );
}

Note createNote() => Note(
  id: 'note-1',
  title: 'Test note',
  content: 'Test content',
  createdAt: DateTime.utc(2026, 9, 9),
  updatedAt: DateTime.utc(2026, 9, 9),
);

class FakeNotesRepository implements NotesRepository {
  List<Note> notes = [];
  Object? failure;
  int readCount = 0;
  Completer<List<Note>>? readGate;

  void _checkFailure() {
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<List<Note>> getNotes() async {
    readCount++;
    _checkFailure();
    final gate = readGate;
    if (gate != null) return gate.future;
    return List<Note>.of(notes);
  }

  @override
  Future<Note?> getNoteById(String id) async {
    _checkFailure();
    for (final note in notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  @override
  Future<void> saveNote(Note note) async {
    _checkFailure();
    notes = [...notes.where((existing) => existing.id != note.id), note];
  }

  @override
  Future<void> deleteNote(String id) async {
    _checkFailure();
    notes = notes.where((note) => note.id != id).toList();
  }

  @override
  Stream<List<Note>> watchNotes() => throw UnimplementedError();
}
