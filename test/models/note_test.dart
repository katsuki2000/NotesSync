import 'package:flutter_test/flutter_test.dart';
import 'package:notessync/models/note.dart';

void main() {
  group('Note - sérialisation Map/JSON', () {
    final sample = Note(
      id: 'note-1',
      title: 'Ma première note',
      content: '# Titre\n\nCeci est du **markdown**.',
      tags: const ['flutter', 'markdown'],
      createdAt: DateTime.utc(2026, 9, 1, 10, 30),
      updatedAt: DateTime.utc(2026, 9, 2, 8, 0),
      isSynced: true,
    );

    test('round-trip toMap -> fromMap conserve toutes les données', () {
      final map = sample.toMap();
      final restored = Note.fromMap(map);

      expect(restored, equals(sample));
    });

    test('round-trip toJson -> fromJson conserve toutes les données', () {
      final json = sample.toJson();
      final restored = Note.fromJson(json);

      expect(restored, equals(sample));
    });

    test('toMap sérialise les dates en ISO8601 (String)', () {
      final map = sample.toMap();

      expect(map['createdAt'], isA<String>());
      expect(map['createdAt'], sample.createdAt.toIso8601String());
    });

    test('fromMap applique les valeurs par défaut (tags vides, isSynced false)',
        () {
      final minimal = {
        'id': 'note-2',
        'title': 'Note minimale',
        'content': 'contenu',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      };

      final note = Note.fromMap(minimal);

      expect(note.tags, isEmpty);
      expect(note.isSynced, isFalse);
    });
  });

  group('Note - sérialisation Firestore', () {
    test("toFirestore n'inclut pas l'id (déjà porté par le document)", () {
      final note = Note(
        id: 'note-3',
        title: 'Titre',
        content: 'Contenu',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final data = note.toFirestore();

      expect(data.containsKey('id'), isFalse);
    });

    test('fromFirestore réinjecte bien l\'id du document', () {
      final data = {
        'title': 'Titre',
        'content': 'Contenu',
        'tags': <String>[],
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'isSynced': true,
      };

      final note = Note.fromFirestore('doc-id-123', data);

      expect(note.id, 'doc-id-123');
    });

    test('fromFirestore accepte un objet type Timestamp (duck-typing)', () {
      final fakeTimestamp = _FakeTimestamp(DateTime.utc(2026, 5, 5, 12, 0));

      final data = {
        'title': 'Titre',
        'content': 'Contenu',
        'tags': <String>[],
        'createdAt': fakeTimestamp,
        'updatedAt': fakeTimestamp,
        'isSynced': false,
      };

      final note = Note.fromFirestore('doc-id-456', data);

      expect(note.createdAt, DateTime.utc(2026, 5, 5, 12, 0));
    });
  });

  group('Note - gestion des erreurs de désérialisation', () {
    test('lève une exception si un champ requis est manquant', () {
      final incomplete = {
        'id': 'note-4',
        'title': 'Titre',
        // 'content' manquant volontairement
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      };

      expect(
        () => Note.fromMap(incomplete),
        throwsA(isA<NoteSerializationException>()),
      );
    });

    test('lève une exception si un champ requis est null', () {
      final withNull = {
        'id': 'note-5',
        'title': null,
        'content': 'Contenu',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      };

      expect(
        () => Note.fromMap(withNull),
        throwsA(isA<NoteSerializationException>()),
      );
    });

    test('lève une exception si une date est mal formatée', () {
      final badDate = {
        'id': 'note-6',
        'title': 'Titre',
        'content': 'Contenu',
        'createdAt': 'pas-une-date',
        'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      };

      expect(
        () => Note.fromMap(badDate),
        throwsA(isA<NoteSerializationException>()),
      );
    });

    test('lève une exception si le titre est une chaîne vide', () {
      final emptyTitle = {
        'id': 'note-7',
        'title': '',
        'content': 'Contenu',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      };

      expect(
        () => Note.fromMap(emptyTitle),
        throwsA(isA<NoteSerializationException>()),
      );
    });

    test('le message d\'erreur identifie clairement le champ fautif', () {
      final incomplete = {
        'id': 'note-8',
        'content': 'Contenu',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'updatedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      };

      try {
        Note.fromMap(incomplete);
        fail('Une NoteSerializationException aurait dû être levée');
      } on NoteSerializationException catch (e) {
        expect(e.message, contains('title'));
      }
    });
  });

  group('Note - copyWith', () {
    test('modifie uniquement les champs spécifiés', () {
      final original = Note(
        id: 'note-9',
        title: 'Titre original',
        content: 'Contenu original',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final modified = original.copyWith(title: 'Nouveau titre');

      expect(modified.title, 'Nouveau titre');
      expect(modified.content, original.content);
      expect(modified.id, original.id);
    });
  });
}

/// Faux Timestamp Firestore pour tester le duck-typing de `_parseDate`
/// sans dépendre du package `cloud_firestore` dans les tests du modèle.
class _FakeTimestamp {
  final DateTime _date;
  const _FakeTimestamp(this._date);
  DateTime toDate() => _date;
}
