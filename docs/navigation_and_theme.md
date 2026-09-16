# Navigation and theme preferences

## Navigation (T-17)

`MyApp` opens the Riverpod-backed note list. Named routes are centralized in
`NoteRoutes` and built by `NotesRouter`:

| Route | Arguments | Purpose |
| --- | --- | --- |
| `/` | None | List local notes |
| `/notes/editor` | Optional `Note` | Create or edit a note |
| `/notes/preview` | `NotePreviewArguments` | Preview saved content or an editor draft |

Routes use short slide/fade transitions and respect the platform's reduced-motion
setting. Previewing a draft leaves the editor mounted. Returning to edit therefore
preserves text and selection. Opening the editor from a list preview replaces the
preview route, so Back returns to the list.

The editor receives a save callback rather than accessing Hive directly. The
callback uses the existing notes provider, including its request serialization
and list refresh. A draft retains its identifier, creation time, and tags across
saves. Both toolbar Back and system Back save dirty changes; save failures keep
the editor open. Empty content is rejected before persistence because the existing
`Note.fromMap` contract requires nonempty content.

## Local theme (T-18)

`ThemePreference` and the local/remote repository contracts live in the domain
layer. `HiveThemeRepository` uses a separate `theme_preferences` box. Startup
opens that box before constructing the app, so cached preferences are available
on the first frame. `MaterialApp.themeMode` follows `themeProvider` on every route.

Preferences are cached separately for each UID and for the signed-out guest.
Switching accounts restores that account's cache, defaulting to light if absent.
Guest settings are not copied into another account. Each toggle persists locally
before it becomes the active theme, independently of pending network requests.

```dart
await ref.read(themeProvider.notifier).toggle();
await ref.read(themeProvider.notifier).setTheme(AppTheme.dark);
final themeState = ref.watch(themeProvider);
```

## Remote theme (T-19)

The Firestore adapter reads and writes this document:

```text
users/{authenticatedUid}/preferences/theme
  theme: "light" | "dark"
  updatedAt: integer milliseconds since epoch
```

`ThemeController` synchronizes on creation/sign-in, on toggles, on app resume, and
through the Retry action. Local pending flags survive restarts. Offline failures
leave the local theme usable; they are exposed in `ThemeState.sync`. Local storage
failures preserve the last successfully persisted theme. A subsequent toggle can
retry a failed local change; Retry reconciles the currently persisted preference.

Pending changes are reconciled inside a Firestore transaction. The newest
timestamp wins; the remote value wins ties. This assumes reasonably comparable
device clocks. A server read without pending edits retrieves the saved remote
preference. Remote updates become visible at the next synchronization trigger;
this implementation does not maintain a continuous snapshot subscription.

Requests are bound to the UID captured by their controller. Account changes
dispose the previous controller, and stale results cannot update the new account's
UI or local cache. A newer local toggle is also protected from older responses.

## Firebase setup

Existing Firebase configuration and authentication are reused. Anonymous sign-in
runs without blocking the local UI. Anonymous accounts have their own UID; sharing
preferences across devices requires signing into the same persistent account.

The updated `firestore.rules` permits only the authenticated owner to read or
write the theme document and validates its fields. Existing note permissions are
preserved. Deploy these rules to the intended Firebase project before using cloud
theme sync:

```sh
firebase deploy --only firestore:rules
```

No live Firebase writes or rules deployments are part of the implementation tests.
For Firebase's underlying guarantees, see the official documentation on
[transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)
and [authentication-based rules](https://firebase.google.com/docs/firestore/security/rules-conditions).

## Verification

```sh
flutter pub get
dart analyze .
flutter test
```

Tests cover routing, draft preservation, save failures, repeated saves, app-wide
theme changes, Hive persistence, offline retry, rapid toggles, account changes,
stale responses, and Firestore conflict resolution.
The original counter smoke test is replaced by navigation tests for the actual
application. Existing note/model/synchronization tests remain in the suite.
Repository tests use `fake_cloud_firestore`. Security rules require the actual
Firestore emulator because the fake does not support schema-validation rules.
Run the separate rules suite with Node.js and Java installed:

```sh
cd tools/firestore_rules
npm ci
npm test
```

The rules suite uses only the local `demo-notessync` project. It checks owner
access, denied guest/cross-account access, field validation, and preservation of
existing note permissions. `firebase.json` includes the rules path needed for
both emulator testing and subsequent deployment.
