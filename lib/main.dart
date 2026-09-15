import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'Services/auth_service.dart';
import 'services/hive_service.dart';
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
  await Hive.openBox<Map<dynamic, dynamic>>(HiveService.boxName);
  final themeBox = await Hive.openBox<Map<dynamic, dynamic>>(
    HiveThemeRepository.boxName,
  );
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final authService = AuthService();
  if (authService.currentUser == null) {
    // Local notes and theme settings remain available while sign-in is pending.
    unawaited(
      authService.signInAnonymously().then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Anonymous sign-in is currently unavailable.');
        },
      ),
    );
  }
  runApp(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        localThemeRepositoryProvider.overrideWithValue(
          HiveThemeRepository(themeBox),
        ),
        notesRepositoryProvider.overrideWithValue(
          HiveNotesRepository(HiveService()),
        ),
        remoteNotesRepositoryProvider.overrideWith((ref) {
          final user = ref.watch(authStateProvider).asData?.value;
          if (user == null) {
            throw StateError('Sign in before synchronizing notes.');
          }
          return FirestoreNotesRepository(
            firestoreService: ref.watch(firestoreSyncServiceProvider),
            userId: user.uid,
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
      onGenerateRoute: (settings) => NotesRouter.generate(settings, ref),
    );
  }
}
