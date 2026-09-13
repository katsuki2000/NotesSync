import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Référence vers la collection des notes d'un utilisateur spécifique
  CollectionReference<Map<String, dynamic>> _userNotesRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('notes');
  }

  // UPLOAD : Envoyer ou mettre à jour une note sur Firestore
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
      throw Exception('Erreur lors de la synchronisation vers Firestore: $e');
    }
  }

  // DOWNLOAD : Récupérer toutes les notes distantes d'un utilisateur
  Future<List<Map<String, dynamic>>> downloadNotes(String userId) async {
    try {
      final snapshot = await _userNotesRef(userId).get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Erreur lors du téléchargement depuis Firestore: $e');
    }
  }

  // DELETE : Supprimer une note distante
  Future<void> deleteNote({
    required String userId,
    required String noteId,
  }) async {
    try {
      await _userNotesRef(userId).doc(noteId).delete();
    } catch (e) {
      throw Exception('Erreur lors de la suppression sur Firestore: $e');
    }
  }
}
