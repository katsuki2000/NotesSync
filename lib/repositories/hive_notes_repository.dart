import '../models/note.dart';
import '../services/hive_service.dart';
import 'notes_repository.dart';

/// Adapts the Hive storage service to the shared notes repository contract.
class HiveNotesRepository implements NotesRepository {
  HiveNotesRepository(this._hiveService);

  final HiveService _hiveService;

  @override
  Future<List<Note>> getNotes() async => _hiveService.getNotes();

  @override
  Future<Note?> getNoteById(String id) async => _hiveService.getNoteById(id);

  @override
  Future<void> saveNote(Note note) => _hiveService.saveNote(note);

  @override
  Future<void> deleteNote(String id) => _hiveService.deleteNote(id);

  @override
  Stream<List<Note>> watchNotes() => const Stream<List<Note>>.empty();
}
