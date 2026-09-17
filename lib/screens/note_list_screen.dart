import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/navigation/note_routes.dart';
import '../presentation/providers/notes_provider.dart';
import '../presentation/providers/notes_sync_provider.dart';
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 13,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Guest',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
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
            icon: Icon(isGuest ? Icons.login_rounded : Icons.logout_rounded),
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
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.note_alt_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notes yet. Create your first note.',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(notesSyncProvider.notifier).synchronize(),
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
                                Icons.delete_outline_rounded,
                                color: Theme.of(context).colorScheme.onError,
                              ),
                            ),
                            confirmDismiss: (_) =>
                                _confirmDelete(context, note.title),
                            onDismissed: (_) => ref
                                .read(notesProvider.notifier)
                                .deleteNote(note.id),
                            child: ListTile(
                              leading: Icon(
                                note.isSynced
                                    ? Icons.cloud_done_rounded
                                    : Icons.cloud_off_rounded,
                                size: 20,
                                color: note.isSynced
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                              ),
                              title: Text(note.title),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    note.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (note.tags.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        for (final tag in note.tags)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .secondaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              tag,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSecondaryContainer,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
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
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
