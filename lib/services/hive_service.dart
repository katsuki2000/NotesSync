import 'package:hive_flutter/hive_flutter.dart';

import '../models/note.dart';

class HiveService {
  static const String boxName = 'notes_box';

  Box<Note> get _box => Hive.box<Note>(boxName);

  // Read (Obtenir toutes les notes)
  List<Note> getNotes() {
    return _box.values.toList();
  }

  // Read (Obtenir une note par son id)
  Note? getNoteById(String id) {
    try {
      return _box.values.firstWhere((note) => note.id == id);
    } catch (_) {
      return null;
    }
  }

  // Create / Update (Ajouter ou mettre à jour)
  Future<void> saveNote(Note note) async {
    await _box.put(note.id, note);
  }

  // Delete (Supprimer une note)
  Future<void> deleteNote(String id) async {
    await _box.delete(id);
  }

  // Clear (Vider la boîte locale si besoin)
  Future<void> clearAll() async {
    await _box.clear();
  }
}
