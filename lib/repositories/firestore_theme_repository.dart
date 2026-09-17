import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/models/theme_preference.dart';
import '../domain/repositories/theme_repository.dart';

class FirestoreThemeRepository implements RemoteThemeRepository {
  FirestoreThemeRepository(this._firestore);
  final FirebaseFirestore _firestore;

  @override
  Future<ThemePreference?> synchronize(
    String userId,
    ThemePreference? local,
  ) async {
    if (userId.isEmpty || userId.contains('/')) {
      throw ArgumentError.value(userId, 'userId', 'Invalid user identifier.');
    }
    final document = _firestore
        .collection('users')
        .doc(userId)
        .collection('preferences')
        .doc('theme');
    if (local == null) {
      final snapshot = await document.get(
        const GetOptions(source: Source.server),
      );
      final data = snapshot.data();
      return data == null ? null : ThemePreference.fromMap(data).acknowledged();
    }
    return _firestore.runTransaction<ThemePreference>((transaction) async {
      final snapshot = await transaction.get(document);
      final data = snapshot.data();
      final remote = data == null ? null : ThemePreference.fromMap(data);
      if (remote != null && remote.updatedAt >= local.updatedAt) {
        return remote.acknowledged();
      }
      transaction.set(document, {
        'theme': local.theme.name,
        'updatedAt': local.updatedAt,
      });
      return local.acknowledged();
    });
  }
}
