import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:notessync/domain/models/theme_preference.dart';
import 'package:notessync/repositories/firestore_theme_repository.dart';
import 'package:notessync/repositories/hive_theme_repository.dart';

void main() {
  test(
    'Hive preserves theme, pending status, and account isolation after reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'notessync-theme-',
      );
      Hive.init(directory.path);
      addTearDown(() async {
        await Hive.close();
        await directory.delete(recursive: true);
      });
      var box = await Hive.openBox<Map<dynamic, dynamic>>(
        HiveThemeRepository.boxName,
      );
      final repository = HiveThemeRepository(box);
      await repository.write(
        'alice',
        const ThemePreference(
          theme: AppTheme.dark,
          updatedAt: 10,
          pending: true,
        ),
      );
      await repository.write(null, const ThemePreference());
      await box.close();
      box = await Hive.openBox<Map<dynamic, dynamic>>(
        HiveThemeRepository.boxName,
      );
      final restored = HiveThemeRepository(box);
      expect(restored.read('alice')?.theme, AppTheme.dark);
      expect(restored.read('alice')?.pending, isTrue);
      expect(restored.read(null)?.theme, AppTheme.light);
      expect(restored.read('bob'), isNull);
    },
  );

  test('Firestore stores the theme in the correct account document', () async {
    final firestore = FakeFirebaseFirestore();
    final repository = FirestoreThemeRepository(firestore);
    expect(await repository.synchronize('alice', null), isNull);
    await repository.synchronize(
      'alice',
      const ThemePreference(theme: AppTheme.dark, updatedAt: 10, pending: true),
    );
    expect(
      (await firestore.doc('users/alice/preferences/theme').get()).data(),
      {'theme': 'dark', 'updatedAt': 10},
    );
    expect((await repository.synchronize('alice', null))?.theme, AppTheme.dark);
    expect(await repository.synchronize('bob', null), isNull);
  });

  test(
    'Firestore keeps newer remote values and breaks timestamp ties remotely',
    () async {
      final firestore = FakeFirebaseFirestore();
      final repository = FirestoreThemeRepository(firestore);
      await firestore.doc('users/alice/preferences/theme').set({
        'theme': 'dark',
        'updatedAt': 20,
      });
      for (final timestamp in [10, 20]) {
        final result = await repository.synchronize(
          'alice',
          ThemePreference(
            theme: AppTheme.light,
            updatedAt: timestamp,
            pending: true,
          ),
        );
        expect(result?.theme, AppTheme.dark);
        expect(result?.pending, isFalse);
      }
      final result = await repository.synchronize(
        'alice',
        const ThemePreference(
          theme: AppTheme.light,
          updatedAt: 21,
          pending: true,
        ),
      );
      expect(result?.theme, AppTheme.light);
      expect((await repository.synchronize('alice', null))?.updatedAt, 21);
    },
  );

  test('malformed remote preferences fail without being overwritten', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.doc('users/alice/preferences/theme').set({
      'theme': 'invalid',
      'updatedAt': 20,
    });
    await expectLater(
      FirestoreThemeRepository(firestore).synchronize('alice', null),
      throwsFormatException,
    );
  });
}
