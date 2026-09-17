import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Flux d'état de l'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Connexion anonyme
  Future<UserCredential> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      throw Exception('Anonymous sign-in error: ${e.message}');
    }
  }

  // Connexion Email/Mot de passe
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception('Sign-in error: ${e.message}');
    }
  }

  // Inscription Email/Mot de passe
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception('Sign-up error: ${e.message}');
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
