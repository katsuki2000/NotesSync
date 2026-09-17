import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notessync/services/auth_service.dart';
import 'package:notessync/services/firestore_sync_service.dart';

// Provider pour AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// StreamProvider pour suivre l'état d'authentification de l'utilisateur
final authStateProvider = StreamProvider((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
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

// Provider pour FirestoreSyncService
final firestoreSyncServiceProvider = Provider<FirestoreSyncService>((ref) {
  return FirestoreSyncService();
});
