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

  /// Suppression douce (tombstone) : la note n'est pas retirée du stockage,
  /// elle est marquée deletedAt=now et réécrite. Ça permet à
  /// NotesSyncService de propager la suppression vers l'autre replica au
  /// lieu de la recréer (voir note_conflict_resolver.dart / synchronize()).
  @override
  Future<void> deleteNote(String id) async {
    final existing = _hiveService.getNoteById(_userId, id);
    if (existing == null) return;
    final now = DateTime.now().toUtc();
    await _hiveService.saveNote(
      _userId,
      existing.copyWith(deletedAt: now, updatedAt: now, isSynced: false),
    );
  }

  @override
  Stream<List<Note>> watchNotes() => const Stream<List<Note>>.empty();
}
