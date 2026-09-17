import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // `late` so constructing AuthService (e.g. a test subclass overriding
  // every member) never touches Firebase unless a real method runs.
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInReady = false;

  // google_sign_in v7 requires an explicit initialize() call before any
  // other method. Android picks up its OAuth client id automatically from
  // google-services.json; a web or iOS build would need to pass clientId /
  // serverClientId here once those platforms are configured in Firebase.
  Future<void> _ensureGoogleSignInReady() async {
    if (_googleSignInReady) return;
    await _googleSignIn.initialize();
    _googleSignInReady = true;
  }

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

  // Réinitialisation du mot de passe
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception('Password reset error: ${e.message}');
    }
  }

  // Connexion Google
  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleSignInReady();
    try {
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      return await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      throw Exception('Google sign-in error: ${e.description ?? e.code}');
    } on FirebaseAuthException catch (e) {
      throw Exception('Google sign-in error: ${e.message}');
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
