import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/navigation/note_routes.dart';
import '../presentation/providers/notes_provider.dart';
import '../presentation/providers/sync_providers.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/widgets/theme_toggle_button.dart';

class NoteListScreen extends ConsumerWidget {
  const NoteListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final theme = ref.watch(themeProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('NotesSync'),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(authServiceProvider).signOut(),
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (theme.sync.hasError)
            MaterialBanner(
              content: const Text('Unable to finish updating your theme.'),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(themeProvider.notifier).synchronize(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          Expanded(
            child: notes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: TextButton(
                  onPressed: () => ref.read(notesProvider.notifier).loadNotes(),
                  child: const Text('Unable to load notes. Retry'),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(
                      child: Text('No notes yet. Create your first note.'),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(notesProvider.notifier).loadNotes(),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final note = items[index];
                          return ListTile(
                            key: ValueKey(note.id),
                            title: Text(note.title),
                            subtitle: Text(
                              note.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => Navigator.of(context)
                                .pushNamed(NoteRoutes.editor, arguments: note),
                            trailing: IconButton(
                              tooltip: 'Preview note',
                              icon: const Icon(Icons.visibility_outlined),
                              onPressed: () => Navigator.of(context).pushNamed(
                                NoteRoutes.preview,
                                arguments: NotePreviewArguments(note),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create note',
        onPressed: () => Navigator.of(context).pushNamed(NoteRoutes.editor),
        child: const Icon(Icons.add),
      ),
    );
  }
}
