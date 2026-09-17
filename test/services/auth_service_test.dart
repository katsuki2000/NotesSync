import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:notessync/services/auth_service.dart';

/// Fake Google Sign-In *platform* implementation.
///
/// `google_sign_in`'s [GoogleSignIn] is a singleton that talks to a platform
/// channel; the officially supported test seam is to swap out
/// [GoogleSignInPlatform.instance] instead of trying to mock [GoogleSignIn]
/// itself (see the package's own README/tests). Only [init] and
/// [authenticate] are exercised by [AuthService.signInWithGoogle] — every
/// other member is unused in that path and left throwing.
class FakeGoogleSignInPlatform extends GoogleSignInPlatform {
  AuthenticationResults? authenticateResult;
  GoogleSignInException? authenticateError;

  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    if (authenticateError != null) throw authenticateError!;
    return authenticateResult!;
  }

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) => null;

  @override
  bool supportsAuthenticate() => true;

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

void main() {
  group('AuthService (email/password/anonymous/reset)', () {
    late MockFirebaseAuth mockAuth;
    late AuthService authService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      authService = AuthService(auth: mockAuth);
    });

    test('signInAnonymously returns a UserCredential for an anonymous user', () async {
      final credential = await authService.signInAnonymously();

      expect(credential.user, isNotNull);
      expect(credential.user!.isAnonymous, isTrue);
      expect(authService.currentUser, isNotNull);
    });

    test(
      'signInWithEmailAndPassword succeeds for a pre-registered user',
      () async {
        final existingUser = MockUser(
          uid: 'uid-1',
          email: 'maha@example.com',
        );
        mockAuth = MockFirebaseAuth(mockUser: existingUser);
        authService = AuthService(auth: mockAuth);

        final credential = await authService.signInWithEmailAndPassword(
          email: 'maha@example.com',
          password: 'correct-password',
        );

        expect(credential.user?.email, 'maha@example.com');
      },
    );

    test(
      'signInWithEmailAndPassword surfaces a readable message on failure',
      () async {
        whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
            .on(mockAuth)
            .thenThrow(
              FirebaseAuthException(code: 'invalid-credential'),
            );

        await expectLater(
          authService.signInWithEmailAndPassword(
            email: 'maha@example.com',
            password: 'wrong-password',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Incorrect email or password'),
            ),
          ),
        );
      },
    );

    test('signUpWithEmailAndPassword creates a new account', () async {
      final credential = await authService.signUpWithEmailAndPassword(
        email: 'new-user@example.com',
        password: 'p@ssw0rd',
      );

      expect(credential.user?.email, 'new-user@example.com');
    });

    test('signUpWithEmailAndPassword translates email-already-in-use', () async {
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(mockAuth)
          .thenThrow(
            FirebaseAuthException(code: 'email-already-in-use'),
          );

      await expectLater(
        authService.signUpWithEmailAndPassword(
          email: 'taken@example.com',
          password: 'p@ssw0rd',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('An account already exists'),
          ),
        ),
      );
    });

    test('sendPasswordResetEmail completes without throwing', () async {
      await expectLater(
        authService.sendPasswordResetEmail(email: 'maha@example.com'),
        completes,
      );
    });

    test('signOut clears the current user', () async {
      await authService.signInAnonymously();
      expect(authService.currentUser, isNotNull);

      await authService.signOut();

      expect(authService.currentUser, isNull);
    });
  });

  group('AuthService.signInWithGoogle', () {
    late MockFirebaseAuth mockAuth;
    late FakeGoogleSignInPlatform fakePlatform;
    late AuthService authService;

    setUpAll(() {
      // GoogleSignIn.instance is a process-wide singleton that must be
      // initialize()d before use; the fake platform is swapped in once here
      // and reused (mutated per test) rather than re-registered per test.
      GoogleSignInPlatform.instance = FakeGoogleSignInPlatform();
    });

    setUp(() {
      mockAuth = MockFirebaseAuth();
      authService = AuthService(auth: mockAuth);
      fakePlatform = GoogleSignInPlatform.instance as FakeGoogleSignInPlatform;
      fakePlatform.authenticateResult = null;
      fakePlatform.authenticateError = null;
    });

    test('exchanges a Google idToken for a Firebase session', () async {
      fakePlatform.authenticateResult = AuthenticationResults(
        user: const GoogleSignInUserData(
          email: 'maha@gmail.com',
          id: 'google-uid-1',
          displayName: 'Maha',
        ),
        authenticationTokens: const AuthenticationTokenData(
          idToken: 'fake-id-token',
        ),
      );

      final credential = await authService.signInWithGoogle();

      expect(credential.user, isNotNull);
    });

    test('wraps a cancelled Google sign-in as a readable error', () async {
      fakePlatform.authenticateError = GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'User canceled the sign-in flow.',
      );

      await expectLater(
        authService.signInWithGoogle(),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('User canceled the sign-in flow'),
          ),
        ),
      );
    });
  });
}
