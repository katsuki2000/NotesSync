import '../services/firestore_sync_service.dart';
import '../models/note.dart';
import 'notes_repository.dart';

/// Adapts the Firestore synchronization service to the notes repository contract.
class FirestoreNotesRepository implements NotesRepository {
  FirestoreNotesRepository({
    required this._firestoreService,
    required this._userId,
  });

  final FirestoreSyncService _firestoreService;
  final String _userId;

  @override
  Future<List<Note>> getNotes() async {
    final data = await _firestoreService.downloadNotes(_userId);
    return data.map(Note.fromMap).toList();
  }

  @override
  Future<Note?> getNoteById(String id) async {
    final notes = await getNotes();
    for (final note in notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  @override
  Future<void> saveNote(Note note) => _firestoreService.uploadNote(
    userId: _userId,
    noteId: note.id,
    noteData: note.toFirestore(),
  );

  /// Suppression douce (tombstone), même logique que HiveNotesRepository —
  /// voir son commentaire pour le pourquoi.
  @override
  Future<void> deleteNote(String id) async {
    final existing = await getNoteById(id);
    if (existing == null) return;
    final now = DateTime.now().toUtc();
    await saveNote(
      existing.copyWith(deletedAt: now, updatedAt: now, isSynced: false),
    );
  }

  @override
  Stream<List<Note>> watchNotes() => const Stream<List<Note>>.empty();
}
