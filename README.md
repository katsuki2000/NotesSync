# NotesSync

Application Flutter de prise de notes en Markdown, avec persistance locale hors-ligne et synchronisation Firestore (offline-first).

## Fonctionnalités

- **Notes Markdown** : création, édition et suppression de notes avec titre, contenu Markdown, tags et horodatage
- **Persistance locale** avec [Hive](https://pub.dev/packages/hive), l'app reste utilisable hors-ligne
- **Synchronisation Firestore** offline-first avec résolution de conflits par horodatage (`last-write-wins`)
- **Authentification** Firebase (email/mot de passe ou anonyme)
- **Éditeur Markdown** avec aperçu en temps réel
- **Thème clair/sombre** persistant localement et synchronisé via Firestore par compte utilisateur

## Stack technique

| Domaine | Techno |
| --- | --- |
| Framework | Flutter |
| State management | Riverpod |
| Persistance locale | Hive |
| Backend | Firebase (Auth + Cloud Firestore) |
| Rendu Markdown | flutter_markdown_plus |

## Structure du projet

```
lib/
├── models/         # Modèle de données Note (sérialisation JSON / Hive / Firestore)
├── repositories/   # Contrat NotesRepository + implémentations Hive et Firestore
├── services/       # auth_service, firestore_sync_service, hive_service
├── screens/        # Écrans : liste des notes, éditeur, aperçu
├── application/     # Services applicatifs
├── presentation/    # Providers Riverpod, routing
└── main.dart

docs/
├── notes_synchronization.md   # Détail de la logique de sync offline-first
└── navigation_and_theme.md    # Détail navigation, thème local/distant

tools/firestore_rules/  # Suite de tests des règles de sécurité Firestore
```

## Installation

### Prérequis

- Flutter SDK (Dart >= 3.13.0)
- Un projet Firebase avec Firestore et Authentication activés

### Étapes

```sh
git clone <url-du-repo>
cd notessync
flutter pub get
```

Configurer Firebase pour le projet (fichier `firebase_options.dart` déjà présent dans `lib/`, à régénérer avec la FlutterFire CLI si vous utilisez votre propre projet Firebase) :

```sh
flutterfire configure
```

Déployer les règles de sécurité Firestore :

```sh
firebase deploy --only firestore:rules
```

Lancer l'application :

```sh
flutter run
```

## Tests

```sh
flutter pub get
dart analyze .
flutter test
```

Les règles de sécurité Firestore ont leur propre suite (nécessite l'émulateur Firestore, Node.js et Java) :

```sh
cd tools/firestore_rules
npm ci
npm test
```

## Documentation complémentaire

- [`docs/notes_synchronization.md`](docs/notes_synchronization.md) — logique de synchronisation offline-first et résolution de conflits
- [`docs/navigation_and_theme.md`](docs/navigation_and_theme.md) — navigation entre écrans, gestion du thème local et distant

## Contributeurs

- **RAILALA Mahalahatse** — Chef de groupe : architecture, modèle de données, intégration finale
- **DERA Check Abdoul Moutala** — Authentification & synchronisation Firestore
- **Salif Mohamed Ouattara** — Logique de synchronisation avancée, state management
