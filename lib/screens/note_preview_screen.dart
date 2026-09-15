import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../presentation/navigation/note_routes.dart';
import '../presentation/widgets/theme_toggle_button.dart';

class NotePreviewScreen extends StatelessWidget {
  const NotePreviewScreen({super.key, required this.arguments});
  final NotePreviewArguments arguments;

  @override
  Widget build(BuildContext context) {
    final note = arguments.note;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview'),
        actions: [
          IconButton(
            tooltip: 'Edit note',
            onPressed: () {
              if (arguments.returnToEditor) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context)
                    .pushReplacementNamed(NoteRoutes.editor, arguments: note);
              }
            },
            icon: const Icon(Icons.edit_outlined),
          ),
          const ThemeToggleButton(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(note.title, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 24),
            MarkdownBody(
              data: note.content.isEmpty ? '_No content yet._' : note.content,
              selectable: true,
            ),
          ],
        ),
      ),
    );
  }
}
