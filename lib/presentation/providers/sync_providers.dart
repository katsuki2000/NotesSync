import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notessync/Services/auth_service.dart';
import 'package:notessync/firestore_sync_service.dart';

// Provider pour AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// StreamProvider pour suivre l'état d'authentification de l'utilisateur
final authStateProvider = StreamProvider((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

// Provider pour FirestoreSyncService
final firestoreSyncServiceProvider = Provider<FirestoreSyncService>((ref) {
  return FirestoreSyncService();
});
