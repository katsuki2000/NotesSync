import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/note.dart';
import '../../screens/note_editor_screen.dart';
import '../../screens/note_list_screen.dart';
import '../../screens/note_preview_screen.dart';
import '../providers/notes_provider.dart';
import 'note_routes.dart';

abstract final class NotesRouter {
  static Route<void> generate(RouteSettings settings, WidgetRef ref) {
    final arguments = settings.arguments;
    final Widget screen;
    if (settings.name == NoteRoutes.list) {
      screen = const NoteListScreen();
    } else if (settings.name == NoteRoutes.editor &&
        (arguments == null || arguments is Note)) {
      screen = Builder(
        builder: (context) => NoteEditorScreen(
          note: arguments as Note?,
          onSave: (note) async {
            await ref.read(notesProvider.notifier).updateNote(note);
            final result = ref.read(notesProvider);
            if (result.hasError) {
              Error.throwWithStackTrace(result.error!, result.stackTrace!);
            }
          },
          onPreview: (note) => Navigator.of(context).pushNamed(
            NoteRoutes.preview,
            arguments: NotePreviewArguments(note, returnToEditor: true),
          ),
        ),
      );
    } else if (settings.name == NoteRoutes.preview &&
        arguments is NotePreviewArguments) {
      screen = NotePreviewScreen(arguments: arguments);
    } else {
      screen = Scaffold(
        appBar: AppBar(title: const Text('Page not found')),
        body: const Center(child: Text('This note route is unavailable.')),
      );
    }
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curved = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: curved.drive(
              Tween(begin: const Offset(0.04, 0), end: Offset.zero),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
