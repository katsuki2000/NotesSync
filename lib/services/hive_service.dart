import 'package:hive_flutter/hive_flutter.dart';

import '../models/note.dart';

/// Persists notes locally in a single shared Hive box, isolated per account
/// via a `userId::noteId` key prefix — the same isolation principle
/// [HiveThemeRepository] already applies to theme preferences. Without this,
/// every account signed in on the same device (including different guest
/// sessions) would read and write the exact same notes.
class HiveService {
  static const String boxName = 'notes_box';

  Box<Map<dynamic, dynamic>> get _box =>
      Hive.box<Map<dynamic, dynamic>>(boxName);

  String _key(String userId, String noteId) => '$userId::$noteId';

  bool _belongsTo(String userId, dynamic key) =>
      key is String && key.startsWith('$userId::');

  // Read all locally stored notes for one account.
  List<Note> getNotes(String userId) {
    return _box.keys
        .where((key) => _belongsTo(userId, key))
        .map((key) => Note.fromMap(Map<String, dynamic>.from(_box.get(key)!)))
        .toList();
  }

  // Read one locally stored note by identifier, for one account.
  Note? getNoteById(String userId, String id) {
    final value = _box.get(_key(userId, id));
    return value == null
        ? null
        : Note.fromMap(Map<String, dynamic>.from(value));
  }

  // Create or update a locally stored note, for one account.
  Future<void> saveNote(String userId, Note note) async {
    await _box.put(_key(userId, note.id), note.toMap());
  }

  // Delete a locally stored note, for one account.
  Future<void> deleteNote(String userId, String id) async {
    await _box.delete(_key(userId, id));
  }

  // Clear every note belonging to one account.
  Future<void> clearAll(String userId) async {
    final keys = _box.keys.where((key) => _belongsTo(userId, key)).toList();
    await _box.deleteAll(keys);
  }
}
