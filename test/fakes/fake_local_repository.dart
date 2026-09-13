import 'in_memory_notes_repository.dart';

/// Simulates local Hive storage without requiring a device or database.
class FakeLocalRepository extends InMemoryNotesRepository {
  FakeLocalRepository({super.notes});
}
