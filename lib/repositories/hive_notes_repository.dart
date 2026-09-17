import '../models/note.dart';
import '../services/hive_service.dart';
import 'notes_repository.dart';

/// Adapts the Hive storage service to the shared notes repository contract,
/// scoped to one account — see [HiveService] for why that scoping matters.
class HiveNotesRepository implements NotesRepository {
  HiveNotesRepository(this._hiveService, this._userId);

  final HiveService _hiveService;
  final String _userId;

  @override
  Future<List<Note>> getNotes() async => _hiveService.getNotes(_userId);

  @override
  Future<Note?> getNoteById(String id) async =>
      _hiveService.getNoteById(_userId, id);

  @override
  Future<void> saveNote(Note note) => _hiveService.saveNote(_userId, note);

  @override
  Future<void> deleteNote(String id) => _hiveService.deleteNote(_userId, id);

  @override
  Stream<List<Note>> watchNotes() => const Stream<List<Note>>.empty();
}
