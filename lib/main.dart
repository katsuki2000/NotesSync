import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'Services/hive_service.dart';
import 'Services/auth_service.dart';
import 'firebase_options.dart';
import 'presentation/providers/notes_provider.dart';
import 'presentation/providers/notes_sync_provider.dart';
import 'presentation/providers/sync_providers.dart';
import 'repositories/firestore_notes_repository.dart';
import 'repositories/hive_notes_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final authService = AuthService();
  if (authService.currentUser == null) {
    await authService.signInAnonymously();
  }
  await Hive.initFlutter();
  await Hive.openBox<Map<dynamic, dynamic>>(HiveService.boxName);

  runApp(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        notesRepositoryProvider.overrideWithValue(
          HiveNotesRepository(HiveService()),
        ),
        remoteNotesRepositoryProvider.overrideWith(
          (ref) => FirestoreNotesRepository(
            firestoreService: ref.watch(firestoreSyncServiceProvider),
            userId: ref.watch(authServiceProvider).currentUser!.uid,
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NotesSync',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'NotesSync Home'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
