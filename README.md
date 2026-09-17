# NotesSync

Application Flutter de prise de notes Markdown, sécurisée et synchronisée, fonctionnant hors-ligne en priorité (offline-first) avec synchronisation Firestore en arrière-plan.

Projet académique réalisé en équipe dans le cadre d'une certification.

## Fonctionnalités

- **Notes Markdown** : création, édition et aperçu en temps réel du rendu Markdown
- **Mode hors-ligne complet** : toutes les opérations (créer/lire/modifier/supprimer) fonctionnent sans connexion, via stockage local Hive **chiffré** (AES-256, clé gérée par `flutter_secure_storage` — Keychain / Keystore)
- **Synchronisation Firestore** : upload/download automatique des notes dès que la connexion revient, avec résolution des conflits en cas de modification simultanée locale/distante
- **Authentification** : écran de connexion (`LoginScreen`) + `AuthGate` réactif, email/mot de passe ou compte anonyme (Firebase Auth)
- **Thème clair/sombre** : préférence locale immédiate, synchronisée sur Firestore et restaurée sur tout appareil connecté au même compte
- **Règles de sécurité Firestore** : chaque utilisateur n'a accès qu'à ses propres notes
- **CI** : analyse statique, formatage et tests exécutés automatiquement (GitHub Actions) sur chaque push/PR vers `main`

## Stack technique

| Domaine | Choix |
|---|---|
| Framework | Flutter (Dart >=3.13.0) |
| État / DI | Riverpod |
| Stockage local | Hive (chiffré AES-256) |
| Stockage clé de chiffrement | flutter_secure_storage |
| Backend | Firebase (Firestore, Auth) |
| Rendu Markdown | flutter_markdown_plus |
| Tests | flutter_test (unitaires, widgets, providers) |
| CI | GitHub Actions (Ubuntu) |

## Architecture

```
lib/
├── models/                 # Modèle de données Note
├── domain/                 # Interfaces et logique métier indépendantes de l'implémentation
│   ├── models/              #   préférence de thème
│   ├── repositories/         #   interface ThemeRepository
│   └── services/             #   résolution de conflits de sync
├── application/
│   └── services/           # Orchestration de la synchronisation (NotesSyncService)
├── repositories/            # Interface NotesRepository/ThemeRepository + implémentations Hive / Firestore
├── services/                # auth_service, firestore_sync_service, hive_service, secure_key_service
├── presentation/
│   ├── navigation/           # Routage entre écrans
│   ├── providers/            # Providers Riverpod (notes, sync, thème)
│   └── widgets/               # Composants réutilisables (sync_button, theme_toggle_button)
└── screens/                  # login_screen, auth_gate, note_list, note_editor, note_preview
```

Le pattern **Repository** est appliqué de bout en bout : `NotesRepository` et `ThemeRepository` sont des interfaces implémentées à la fois par une version Hive (locale) et une version Firestore (distante), injectées via Riverpod dans `main.dart`. Cela permet de tester la logique métier avec des doubles de test (fakes), sans dépendre de Firebase.

## Démarrage

```bash
flutter pub get
flutter run
```

Un projet Firebase doit être configuré (`lib/firebase_options.dart`, `.firebaserc`, déjà fournis) avec Firestore et Authentication activés.

## Tests

```bash
flutter test
```

## Qualité de code

```bash
flutter analyze
dart format --output=none --set-exit-if-changed .
```

Ces vérifications tournent automatiquement en CI (GitHub Actions, `.github/workflows/flutter.yml`) sur chaque push et pull request vers `main`.

## Équipe

Projet réalisé par RAILALA Mahalahatse (lead), DERA Check Abdoul Moutala et Salif Mohamed Ouattara.
