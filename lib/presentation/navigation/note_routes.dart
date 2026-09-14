import '../../models/note.dart';

abstract final class NoteRoutes {
  static const list = '/';
  static const editor = '/notes/editor';
  static const preview = '/notes/preview';
}

class NotePreviewArguments {
  const NotePreviewArguments(this.note, {this.returnToEditor = false});
  final Note note;
  final bool returnToEditor;
}
