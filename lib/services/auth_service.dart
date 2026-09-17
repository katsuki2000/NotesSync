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

  // Turns a FirebaseAuthException's technical code into a short sentence a
  // user can act on. Projects created after Sept 2023 have email enumeration
  // protection enabled by default, so Firebase merges "wrong password" and
  // "no such user" into the single generic `invalid-credential` code (to
  // avoid revealing which emails have an account) — surfacing e.message raw
  // for that code shows confusing text like "malformed or has expired",
  // which reads like a bug rather than "check your email/password".
  String _readableAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'That email address doesn\'t look valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
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
      throw Exception(_readableAuthError(e));
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
      throw Exception(_readableAuthError(e));
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
      throw Exception(_readableAuthError(e));
    }
  }

  // Réinitialisation du mot de passe
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_readableAuthError(e));
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
      throw Exception(_readableAuthError(e));
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
