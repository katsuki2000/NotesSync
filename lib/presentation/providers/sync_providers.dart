import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../services/firestore_sync_service.dart';

// Provider pour AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// StreamProvider pour suivre l'état d'authentification de l'utilisateur
final authStateProvider = StreamProvider((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// The current Firebase user's uid, or null if signed out.
///
/// Same data/loading/error derivation as isSignedInProvider and
/// isAnonymousProvider — do not read authStateProvider.asData?.value
/// directly elsewhere: during the stream's initial AsyncLoading state
/// (e.g. right after a fresh sign-in, before authStateChanges has
/// delivered its first event) that returns null even when a user is
/// already available synchronously via authServiceProvider.currentUser,
/// which previously made notesRepositoryProvider throw on a freshly
/// signed-in session.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref
      .watch(authStateProvider)
      .when(
        data: (user) => user?.uid,
        loading: () => ref.watch(authServiceProvider).currentUser?.uid,
        error: (error, stackTrace) => null,
      );
});

/// True once a Firebase user (anonymous or not) is available.
///
/// Mirrors themeUserIdProvider's own derivation (data/loading/error) from
/// authStateProvider, on purpose: it keeps AuthGate trivially overridable
/// in tests with a plain bool, instead of needing a fake firebase_auth User.
final isSignedInProvider = Provider<bool>((ref) {
  return ref
      .watch(authStateProvider)
      .when(
        data: (user) => user != null,
        loading: () => ref.watch(authServiceProvider).currentUser != null,
        error: (error, stackTrace) => false,
      );
});

/// True while the current session is an anonymous ("guest") account — one
/// with no email/password or Google identity attached. Used to show a
/// guest indicator and offer "sign in" rather than "sign out" in the UI,
/// since ending an anonymous session discards it rather than merely
/// pausing it.
final isAnonymousProvider = Provider<bool>((ref) {
  return ref
      .watch(authStateProvider)
      .when(
        data: (user) => user?.isAnonymous ?? false,
        loading: () =>
            ref.watch(authServiceProvider).currentUser?.isAnonymous ?? false,
        error: (error, stackTrace) => false,
      );
});

// Provider pour FirestoreSyncService
final firestoreSyncServiceProvider = Provider<FirestoreSyncService>((ref) {
  return FirestoreSyncService();
});
