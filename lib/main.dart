import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'screens/auth_gate.dart';
import 'services/auth_service.dart';
import 'services/hive_service.dart';
import 'services/secure_key_service.dart';
import 'domain/models/theme_preference.dart';
import 'firebase_options.dart';
import 'presentation/navigation/notes_router.dart';
import 'presentation/providers/notes_provider.dart';
import 'presentation/providers/notes_sync_provider.dart';
import 'presentation/providers/sync_providers.dart';
import 'presentation/providers/theme_provider.dart';
import 'repositories/firestore_notes_repository.dart';
import 'repositories/hive_notes_repository.dart';
import 'repositories/hive_theme_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Notes and theme preferences are stored locally on the device, so both
  // boxes are encrypted at rest with an AES-256 key that lives only in
  // platform secure storage (Keychain / Keystore), never inside the box
  // itself. See SecureKeyService for details.
  final encryptionKey = await SecureKeyService().getEncryptionKey();
  final cipher = HiveAesCipher(encryptionKey);

  await Hive.openBox<Map<dynamic, dynamic>>(
    HiveService.boxName,
    encryptionCipher: cipher,
  );
  final themeBox = await Hive.openBox<Map<dynamic, dynamic>>(
    HiveThemeRepository.boxName,
    encryptionCipher: cipher,
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final authService = AuthService();
  // Sign-in is now an explicit choice made on LoginScreen (email/password or
  // "continue without an account", which calls signInAnonymously itself) —
  // local notes and theme settings remain usable either way.
  runApp(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        localThemeRepositoryProvider.overrideWithValue(
          HiveThemeRepository(themeBox),
        ),
        notesRepositoryProvider.overrideWith((ref) {
          final uid = ref.watch(currentUserIdProvider);
          if (uid == null) {
            throw StateError('Sign in before accessing local notes.');
          }
          return HiveNotesRepository(HiveService(), uid);
        }),
        remoteNotesRepositoryProvider.overrideWith((ref) {
          final uid = ref.watch(currentUserIdProvider);
          if (uid == null) {
            throw StateError('Sign in before synchronizing notes.');
          }
          return FirestoreNotesRepository(
            firestoreService: ref.watch(firestoreSyncServiceProvider),
            userId: uid,
          );
        }),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(themeProvider.notifier).synchronize());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider).preference.theme;
    return MaterialApp(
      title: 'NotesSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: theme == AppTheme.dark ? ThemeMode.dark : ThemeMode.light,
      home: const AuthGate(),
      onGenerateRoute: (settings) => NotesRouter.generate(settings, ref),
    );
  }
}
