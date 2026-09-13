import 'package:hive/hive.dart';

part 'note_model.g.dart';

@HiveType(typeId: 0)
class NoteModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String content;

  @HiveField(3)
  DateTime updatedAt;

  @HiveField(4)
  bool isSynced;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.isSynced = false,
  });
}
