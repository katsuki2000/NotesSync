import 'package:hive_flutter/hive_flutter.dart';

import '../models/note.dart';

class HiveService {
  static const String boxName = 'notes_box';

  Box<Map<dynamic, dynamic>> get _box =>
      Hive.box<Map<dynamic, dynamic>>(boxName);

  // Read all locally stored notes.
  List<Note> getNotes() {
    return _box.values
        .map((value) => Note.fromMap(Map<String, dynamic>.from(value)))
        .toList();
  }

  // Read one locally stored note by identifier.
  Note? getNoteById(String id) {
    final value = _box.get(id);
    return value == null
        ? null
        : Note.fromMap(Map<String, dynamic>.from(value));
  }

  // Create or update a locally stored note.
  Future<void> saveNote(Note note) async {
    await _box.put(note.id, note.toMap());
  }

  // Delete a locally stored note.
  Future<void> deleteNote(String id) async {
    await _box.delete(id);
  }

  // Clear all locally stored notes.
  Future<void> clearAll() async {
    await _box.clear();
  }
}
