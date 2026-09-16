import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Reference the notes collection for one user.
  CollectionReference<Map<String, dynamic>> _userNotesRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('notes');
  }

  // Upload or update a note in Firestore.
  Future<void> uploadNote({
    required String userId,
    required String noteId,
    required Map<String, dynamic> noteData,
  }) async {
    try {
      await _userNotesRef(userId)
          .doc(noteId)
          .set(noteData, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to upload note to Firestore: $e');
    }
  }

  // Download all notes for one user.
  Future<List<Map<String, dynamic>>> downloadNotes(String userId) async {
    try {
      final snapshot = await _userNotesRef(userId).get();
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      throw Exception('Failed to download notes from Firestore: $e');
    }
  }

  // Delete a note from Firestore.
  Future<void> deleteNote({
    required String userId,
    required String noteId,
  }) async {
    try {
      await _userNotesRef(userId).doc(noteId).delete();
    } catch (e) {
      throw Exception('Failed to delete note from Firestore: $e');
    }
  }
}
