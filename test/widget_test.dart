import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notessync/main.dart';
import 'package:notessync/presentation/providers/notes_provider.dart';
import 'package:notessync/presentation/providers/theme_provider.dart';
import 'package:notessync/screens/note_editor_screen.dart';
import 'package:notessync/screens/note_list_screen.dart';
import 'package:notessync/screens/note_preview_screen.dart';

import 'fakes/fake_local_repository.dart';
import 'fakes/fake_theme_repositories.dart';
import 'fakes/note_fixture.dart';

void main() {
  late FakeLocalRepository notes;
  late FakeLocalThemeRepository theme;

  setUp(() {
    notes = FakeLocalRepository();
    theme = FakeLocalThemeRepository();
  });
  tearDown(() => notes.dispose());

  Widget app() => ProviderScope(
    overrides: [
      notesRepositoryProvider.overrideWithValue(notes),
      localThemeRepositoryProvider.overrideWithValue(theme),
      remoteThemeRepositoryProvider.overrideWithValue(
        FakeRemoteThemeRepository(),
      ),
      themeUserIdProvider.overrideWithValue(null),
    ],
    child: const MyApp(),
  );

  testWidgets(
    'compact editor exposes navigation and theme actions without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Create note'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Save'), findsOneWidget);
      expect(find.byTooltip('Open preview'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'list, editor, and preview preserve drafts and reuse one note identifier',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(NoteListScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Create note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Travel notes');
      await tester.enterText(find.byType(TextField).last, 'First draft');
      await tester.tap(find.byTooltip('Open preview'));
      await tester.pumpAndSettle();
      expect(find.byType(NotePreviewScreen), findsOneWidget);
      expect(find.text('First draft'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit note'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller?.text,
        'First draft',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final first = (await notes.getNotes()).single;
      await tester.enterText(find.byType(TextField).last, 'Second draft');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final second = (await notes.getNotes()).single;
      expect(second.id, first.id);
      expect(second.createdAt, first.createdAt);
      expect(second.content, 'Second draft');
      await tester.tap(find.byTooltip('Back to notes'));
      await tester.pumpAndSettle();
      expect(find.byType(NoteListScreen), findsOneWidget);
      expect(find.text('Travel notes'), findsOneWidget);
    },
  );

  testWidgets(
    'system back saves changes and keeps the editor open on failure',
    (tester) async {
      await notes.saveNote(makeNote());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test note'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Unsaved edit');
      notes.nextWriteError = StateError('Disk unavailable');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NoteEditorScreen), findsOneWidget);
      expect(find.text('Unable to save the note locally.'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NoteListScreen), findsOneWidget);
      expect((await notes.getNotes()).single.content, 'Unsaved edit');
      expect((await notes.getNotes()).single.tags, ['test']);
    },
  );

  testWidgets('list preview opens editor and returns directly to the list', (
    tester,
  ) async {
    await notes.saveNote(makeNote());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Preview note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to notes'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteListScreen), findsOneWidget);
    expect(find.byType(NotePreviewScreen), findsNothing);
  });

  testWidgets('theme toggle updates every route and survives an app rebuild', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to dark theme'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(find.byType(NoteEditorScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.tap(find.byTooltip('Switch to light theme'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
  });
}
