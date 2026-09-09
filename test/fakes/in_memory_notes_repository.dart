import 'dart:async';

import 'package:notessync/models/note.dart';
import 'package:notessync/repositories/notes_repository.dart';

/// Shared in-memory persistence with immutable snapshots and observable writes.
abstract class InMemoryNotesRepository implements NotesRepository {
  InMemoryNotesRepository({Iterable<Note> notes = const []}) {
    for (final note in notes) {
      _notes[note.id] = _copy(note);
    }
  }

  final Map<String, Note> _notes = {};
  final StreamController<List<Note>> _changes =
      StreamController<List<Note>>.broadcast(sync: true);
  bool _closed = false;
  int readCount = 0;
  int saveCount = 0;
  Object? nextWriteError;

  void checkAvailable() {
    if (_closed) throw StateError('Repository is closed.');
  }

  static Note _copy(Note note) =>
      note.copyWith(tags: List<String>.unmodifiable(note.tags));

  List<Note> _snapshot() => List<Note>.unmodifiable(_notes.values.map(_copy));

  @override
  Future<List<Note>> getNotes() async {
    checkAvailable();
    readCount++;
    return _snapshot();
  }

  @override
  Future<Note?> getNoteById(String id) async {
    checkAvailable();
    final note = _notes[id];
    return note == null ? null : _copy(note);
  }

  void _checkWrite() {
    checkAvailable();
    final error = nextWriteError;
    nextWriteError = null;
    if (error != null) throw error;
  }

  @override
  Future<void> saveNote(Note note) async {
    _checkWrite();
    _notes[note.id] = _copy(note);
    saveCount++;
    _changes.add(_snapshot());
  }

  @override
  Future<void> deleteNote(String id) async {
    _checkWrite();
    _notes.remove(id);
    _changes.add(_snapshot());
  }

  @override
  Stream<List<Note>> watchNotes() => Stream<List<Note>>.multi((controller) {
    try {
      checkAvailable();
      final subscription = _changes.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
      controller.add(_snapshot());
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
      controller.close();
    }
  });

  Future<void> dispose() async {
    _closed = true;
    await _changes.close();
  }
}
