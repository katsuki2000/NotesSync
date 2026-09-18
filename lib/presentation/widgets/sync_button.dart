import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notes_sync_provider.dart';

/// Triggers a manual Firestore synchronization pass and reflects its state.
///
/// Kept separate from NoteListScreen so the sync provider chain (and the
/// Firebase auth call it depends on) is only reached when this widget is
/// actually built, and so it stays independently testable.
class SyncButton extends ConsumerWidget {
  const SyncButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(notesSyncProvider);
    return IconButton(
      tooltip: 'Synchronize notes',
      onPressed: sync.isLoading
          ? null
          : () => ref.read(notesSyncProvider.notifier).synchronize(),
      icon: sync.isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              sync.hasError ? Icons.sync_problem_rounded : Icons.sync_rounded,
            ),
    );
  }
}
