import 'in_memory_notes_repository.dart';

/// Simulates remote Firestore storage and network availability.
class FakeRemoteRepository extends InMemoryNotesRepository {
  FakeRemoteRepository({super.notes});

  bool isOnline = true;

  @override
  void checkAvailable() {
    super.checkAvailable();
    if (!isOnline) throw StateError('Remote repository is offline.');
  }
}
