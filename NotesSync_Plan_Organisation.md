# NotesSync — Plan d'organisation & stratégie d'intégration

## 🎯 Contexte

**Projet :** NotesSync — Prise de notes sécurisée en Markdown
**Catégorie :** Systèmes de Gestion & Productivité
**Focus technique :** Local Persistence + Sync Firestore, Data Serialization
**Bonus :** Mode sombre/clair synchronisé
**Chef de groupe :** Toi (RAILALA Mahalahatse)

## 👥 Équipe

| Membre | Niveau | Rôle principal |
|---|---|---|
| Toi | Chef de groupe | Architecture, modèle de données, intégration finale |
| Check (DERA Check Abdoul Moutala) | Solide en Firebase | Auth & Firestore Sync |
| Ouattara (Salif Mohamed Ouattara) | Avancé | Logique de sync avancée, appui intégration |
| Nine (Auga) | À évaluer | Éditeur Markdown & UI |
| Benit (BURIHABWA Béni Patient) | En retard, pas encore Firebase | Persistance locale (Hive) |

## 📅 Timeline retenue

- **Cette semaine** : chacun développe sa partie de son côté, sur sa propre branche.
- **Semaine prochaine** : merge de toutes les branches sur `main`.

⚠️ **Point d'attention deadline** : la certification de tous les membres doit être validée **avant le 16 septembre**. Vérifie avec le mentor si c'est une deadline indépendante du merge de code ou si elle conditionne la présentation finale — ça change la marge de manœuvre réelle.

## 🧩 Découpage des tâches

| ID | Module / Fonctionnalité | Responsable |
|---|---|---|
| T-01 | Modèle de données `Note` (id, titre, contenu md, tags, dates) | Toi |
| T-02 | Sérialisation JSON / mapping Firestore | Toi |
| T-03 | Structure du repo (models/services/screens/providers) | Toi |
| T-04 | Intégration Hive pour la persistance locale | Benit |
| T-05 | CRUD local complet (créer/lire/modifier/supprimer hors-ligne) | Benit |
| T-06 | Écran liste des notes (connecté au stockage local) | Benit |
| T-06bis | Config Firebase console (projet, Firestore + Auth activés, fichiers de config téléchargés) | Check |
| T-07 | Configuration Firebase dans l'app (firebase_options.dart) | Check |
| T-08 | Authentification (email/password ou anonyme) | Check |
| T-09 | Service FirestoreSyncService (upload/download notes) | Check |
| T-10 | Règles de sécurité Firestore (accès par utilisateur) | Check |
| T-11 | Sync bidirectionnelle offline-first (merge local/Firestore) | Ouattara |
| T-12 | Gestion des conflits de synchronisation | Ouattara |
| T-13 | State management global (Provider/Riverpod/Bloc) | Ouattara |
| T-14 | Écran d'édition markdown | Nine |
| T-15 | Aperçu markdown en temps réel | Nine |
| T-16 | Navigation liste / édition / aperçu | Nine |
| T-17 | [Bonus] Toggle thème clair/sombre (local) | Benit |
| T-18 | [Bonus] Sync préférence de thème via Firestore | Benit |
| T-19 | Merge des branches & résolution conflits Git | Toi |
| T-20 | Tests d'intégration bout-en-bout | Toi + Ouattara |
| T-21 | Revue de code finale & préparation démo | Toi |

## 🔗 La dépendance critique à livrer en premier

Tout le monde attend, directement ou indirectement, **T-01 et T-02** (le modèle `Note` et sa sérialisation). Si ces deux tâches traînent, tout le groupe est ralenti même en travaillant "chacun de son côté".

**Action jour 1-2 :** livre un contrat minimal, même incomplet :
- La classe `Note` avec ses champs figés + `toJson()` / `fromJson()`
- Une interface abstraite `NotesRepository` avec juste les signatures (`getNotes()`, `saveNote()`, `deleteNote()`)

Chacun code ensuite **contre cette interface**, sans avoir besoin de se synchroniser en permanence :
- Benit l'implémente en local (Hive)
- Check / Ouattara l'implémentent en Firestore

C'est ce contrat partagé qui permet de vraiment travailler en parallèle sans diverger.

## 🧱 Comment éviter que le travail en silo explose au merge

1. **Un check-point d'intégration à mi-semaine**, même léger (30 min) : chacun pousse l'état de sa branche, tu vérifies juste que le code compile et que les interfaces sont respectées. Objectif : détecter un problème d'interface *avant* la semaine de merge, pas pendant.
2. **Stand-up quotidien (10-15 min)** — trois questions : Qu'as-tu fait hier ? Que fais-tu aujourd'hui ? Y a-t-il un blocage ?
3. **Un "filet de sécurité" pour les merges** : vu son niveau, Ouattara peut t'aider à relire/merger le code de Check et Benit en plus de sa propre tâche.
4. **Règles Git strictes** :
   - Une branche par membre (`feature/local-persistence`, `feature/firestore-sync`, `feature/sync-logic`, `feature/markdown-editor`)
   - Aucun push direct sur `main` — toujours une Pull Request
   - Merge vers `main` uniquement en semaine 2, après validation

5. **Blocage > 24h → escalade immédiate** au mentor, ne pas laisser trainer.

## 📍 État d'avancement

- ✅ T-01, T-02, T-03 — faites (modèle `Note`, interface `NotesRepository`, structure du repo), PR #1
- 🔜 Prochain bloquant réel : **T-06bis (Check)**, config Firebase console — sans elle, T-07/T-08/T-09 ne peuvent pas vraiment démarrer

## ✅ Résumé de la stratégie

| Risque | Parade |
|---|---|
| Tout le monde attend le modèle de données | Livrer T-01/T-02 en priorité absolue, jour 1-2 |
| Le travail en silo diverge trop pour merger en semaine 2 | Interface partagée `NotesRepository` + check-point à mi-semaine |
| Un membre bloqué invisible jusqu'au merge | Stand-up quotidien + règle d'escalade à 24h |
| Merge chaotique en semaine 2 | Branches dédiées, PR obligatoires, Ouattara en appui intégration |
| Deadline certification vs deadline projet floues | Clarifier avec le mentor dès le premier contact |
