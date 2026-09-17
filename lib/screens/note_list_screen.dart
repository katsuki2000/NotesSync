import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/navigation/note_routes.dart';
import '../presentation/providers/notes_provider.dart';
import '../presentation/providers/sync_providers.dart';
import '../presentation/providers/theme_provider.dart';
import '../presentation/widgets/theme_toggle_button.dart';

class NoteListScreen extends ConsumerWidget {
  const NoteListScreen({super.key});

  Future<bool> _confirmDelete(BuildContext context, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('"$title" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider);
    final theme = ref.watch(themeProvider);
    final isGuest = ref.watch(isAnonymousProvider);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('NotesSync'),
            if (isGuest) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Guest',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: isGuest ? 'Sign in' : 'Sign out',
            onPressed: () => ref.read(authServiceProvider).signOut(),
            icon: Icon(isGuest ? Icons.login_outlined : Icons.logout_outlined),
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
                          return Dismissible(
                            key: ValueKey(note.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Theme.of(context).colorScheme.error,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.onError,
                              ),
                            ),
                            confirmDismiss: (_) =>
                                _confirmDelete(context, note.title),
                            onDismissed: (_) => ref
                                .read(notesProvider.notifier)
                                .deleteNote(note.id),
                            child: ListTile(
                              title: Text(note.title),
                              subtitle: Text(
                                note.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => Navigator.of(context).pushNamed(
                                NoteRoutes.editor,
                                arguments: note,
                              ),
                              trailing: IconButton(
                                tooltip: 'Preview note',
                                icon: const Icon(Icons.visibility_outlined),
                                onPressed: () => Navigator.of(context).pushNamed(
                                  NoteRoutes.preview,
                                  arguments: NotePreviewArguments(note),
                                ),
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
