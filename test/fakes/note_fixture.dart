import 'package:notessync/models/note.dart';

Note makeNote({
  String id = 'note-1',
  String content = 'Original content',
  int revision = 0,
  bool isSynced = false,
}) => Note(
  id: id,
  title: 'Test note',
  content: content,
  tags: const ['test'],
  createdAt: DateTime.utc(2026, 9, 9),
  updatedAt: DateTime.utc(2026, 9, 9).add(Duration(minutes: revision)),
  isSynced: isSynced,
);
