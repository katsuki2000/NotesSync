import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notessync/domain/models/theme_preference.dart';
import 'package:notessync/presentation/providers/theme_provider.dart';

import '../../fakes/fake_theme_repositories.dart';

void main() {
  late FakeLocalThemeRepository local;
  late FakeRemoteThemeRepository remote;

  setUp(() {
    local = FakeLocalThemeRepository();
    remote = FakeRemoteThemeRepository();
  });

  test(
    'restores local theme immediately and retrieves the signed-in preference',
    () async {
      local.values['alice'] = const ThemePreference(
        theme: AppTheme.dark,
        updatedAt: 1,
      );
      remote.values['alice'] = const ThemePreference(
        theme: AppTheme.light,
        updatedAt: 2,
      );
      final controller = ThemeController(local, remote, 'alice');
      addTearDown(controller.dispose);
      expect(controller.state.preference.theme, AppTheme.dark);
      await controller.synchronize();
      expect(controller.state.preference.theme, AppTheme.light);
      expect(local.read('alice')?.updatedAt, 2);
    },
  );

  test(
    'guest changes persist across controllers without remote requests',
    () async {
      final controller = ThemeController(local, remote, null);
      await controller.toggle();
      controller.dispose();
      final restored = ThemeController(local, remote, null);
      addTearDown(restored.dispose);
      expect(restored.state.preference.theme, AppTheme.dark);
      expect(remote.requests, isEmpty);
    },
  );

  test('offline changes stay pending and are uploaded on retry', () async {
    remote.offline = true;
    final controller = ThemeController(local, remote, 'alice');
    addTearDown(controller.dispose);
    await controller.setTheme(AppTheme.dark);
    expect(local.read('alice')?.pending, isTrue);
    expect(controller.state.preference.theme, AppTheme.dark);
    expect(controller.state.sync.hasError, isTrue);
    remote.offline = false;
    await controller.synchronize();
    expect(remote.values['alice']?.theme, AppTheme.dark);
    expect(local.read('alice')?.pending, isFalse);
  });

  test(
    'local persistence failure preserves the last successfully saved theme',
    () async {
      final controller = ThemeController(local, remote, null);
      addTearDown(controller.dispose);
      local.failWrites = true;
      await controller.toggle();
      expect(controller.state.preference.theme, AppTheme.light);
      expect(controller.state.sync.hasError, isTrue);
      expect(remote.requests, isEmpty);
    },
  );

  test(
    'local toggles remain responsive and survive an older remote response',
    () async {
      final gate = Completer<ThemePreference?>();
      remote.nextResponse = gate;
      final controller = ThemeController(local, remote, 'alice');
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      final toggle = controller.setTheme(AppTheme.dark);
      await Future<void>.delayed(Duration.zero);
      expect(local.read('alice')?.theme, AppTheme.dark);
      expect(controller.state.preference.theme, AppTheme.dark);
      gate.complete(const ThemePreference(theme: AppTheme.light, updatedAt: 1));
      await toggle;
      expect(controller.state.preference.theme, AppTheme.dark);
      expect(remote.values['alice']?.theme, AppTheme.dark);
    },
  );

  test(
    'rapid toggles are serialized and persist the final selection',
    () async {
      final controller = ThemeController(local, remote, 'alice');
      addTearDown(controller.dispose);
      await Future.wait([
        controller.toggle(),
        controller.toggle(),
        controller.toggle(),
      ]);
      expect(local.read('alice')?.theme, AppTheme.dark);
      expect(remote.values['alice']?.theme, AppTheme.dark);
      expect(local.read('alice')?.pending, isFalse);
    },
  );

  test(
    'account changes isolate caches and ignore the previous account response',
    () async {
      final currentUser = StateProvider<String?>((ref) => 'alice');
      final gate = Completer<ThemePreference?>();
      remote.nextResponse = gate;
      local.values['bob'] = const ThemePreference(
        theme: AppTheme.dark,
        updatedAt: 4,
      );
      final container = ProviderContainer(
        overrides: [
          localThemeRepositoryProvider.overrideWithValue(local),
          remoteThemeRepositoryProvider.overrideWithValue(remote),
          themeUserIdProvider.overrideWith((ref) => ref.watch(currentUser)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(themeProvider, (_, next) {});
      final alice = container.read(themeProvider.notifier).synchronize();
      await Future<void>.delayed(Duration.zero);
      container.read(currentUser.notifier).state = 'bob';
      expect(container.read(themeProvider).preference.theme, AppTheme.dark);
      await container.read(themeProvider.notifier).synchronize();
      gate.complete(
        const ThemePreference(theme: AppTheme.light, updatedAt: 100),
      );
      await alice;
      expect(container.read(themeProvider).preference.theme, AppTheme.dark);
      expect(local.read('bob')?.updatedAt, 4);
      container.read(currentUser.notifier).state = null;
      expect(container.read(themeProvider).preference.theme, AppTheme.light);
    },
  );
}
