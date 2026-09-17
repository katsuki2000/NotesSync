import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/providers/sync_providers.dart';
import 'login_screen.dart';
import 'note_list_screen.dart';

/// Shows [LoginScreen] until a Firebase user (anonymous or not) exists, then
/// the notes app. Reactive: signing out flips this back automatically since
/// it watches isSignedInProvider (derived from authStateProvider).
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    if (!signedIn) {
      final authService = ref.read(authServiceProvider);
      return LoginScreen(
        onSignIn: (email, password) async {
          await authService.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        },
        onSignUp: (email, password) async {
          await authService.signUpWithEmailAndPassword(
            email: email,
            password: password,
          );
        },
        onContinueAsGuest: () async {
          await authService.signInAnonymously();
        },
        onSignInWithGoogle: () async {
          await authService.signInWithGoogle();
        },
        onForgotPassword: (email) async {
          await authService.sendPasswordResetEmail(email: email);
        },
      );
    }
    return const NoteListScreen();
  }
}
