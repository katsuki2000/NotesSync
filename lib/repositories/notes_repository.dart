import '../models/note.dart';

/// Contrat commun de persistance des notes.
///
/// Chaque implémentation respecte cette même interface, ce qui permet
/// à l'équipe de travailler en parallèle sans se bloquer :
/// - `HiveNotesRepository` (Benit) : persistance locale hors-ligne
/// - `FirestoreNotesRepository` (Check/Ouattara) : synchronisation cloud
abstract class NotesRepository {
  /// Récupère toutes les notes disponibles.
  Future<List<Note>> getNotes();

  /// Récupère une note précise par son id, ou null si introuvable.
  Future<Note?> getNoteById(String id);

  /// Crée ou met à jour une note (upsert).
  Future<void> saveNote(Note note);

  /// Supprime une note par son id.
  Future<void> deleteNote(String id);

  /// Flux temps réel des notes (utile pour Firestore, optionnel en local).
  /// Peut être laissé non implémenté (throw UnimplementedError) côté Hive
  /// si non nécessaire dans un premier temps.
  Stream<List<Note>> watchNotes();
}
