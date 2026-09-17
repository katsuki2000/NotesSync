/// Exception levée lorsqu'une désérialisation de [Note] échoue.
///
/// Volontairement distincte des exceptions Dart génériques (FormatException,
/// TypeError...) pour que l'appelant puisse la distinguer facilement et
/// afficher un message clair à l'utilisateur plutôt qu'un crash brut.
class NoteSerializationException implements Exception {
  final String message;
  final Object? cause;

  const NoteSerializationException(this.message, [this.cause]);

  @override
  String toString() =>
      'NoteSerializationException: $message'
      '${cause != null ? ' (cause: $cause)' : ''}';
}

/// Modèle de données représentant une note Markdown.
///
/// Sert de contrat partagé pour toute l'équipe :
/// - `Benit` l'utilise pour la persistance locale (Hive)
/// - `Check` / `Ouattara` l'utilisent pour la sync Firestore
///
/// Le modèle reste volontairement indépendant du package `cloud_firestore` :
/// aucun import Firestore ici, pour que la couche locale (Hive) n'ait pas
/// à dépendre inutilement de Firebase. La conversion des types spécifiques
/// à Firestore (comme `Timestamp`) est gérée via duck-typing dans
/// `_parseDate`, sans importer le package.
class Note {
  final String id;
  final String title;
  final String content; // contenu au format Markdown
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool
  isSynced; // true si la version locale est synchronisée avec Firestore
  final DateTime? deletedAt; // tombstone : non-null si la note a été supprimée

  const Note({
    required this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.deletedAt,
  });

  /// true si la note est un tombstone (supprimée mais conservée pour la
  /// propagation de la suppression entre replicas — voir NotesSyncService).
  bool get isDeleted => deletedAt != null;

  /// Crée une copie de la note avec certains champs modifiés.
  Note copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  // ---------------------------------------------------------------------
  // Sérialisation générique (Hive, cache local, debug...)
  // ---------------------------------------------------------------------

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  /// Reconstruit une [Note] à partir d'une [Map], avec validation stricte.
  ///
  /// Lève une [NoteSerializationException] avec un message clair si un champ
  /// requis est manquant, `null`, ou d'un type inattendu — plutôt que de
  /// laisser Dart planter avec un `TypeError` cryptique en plein milieu de
  /// l'app.
  factory Note.fromMap(Map<String, dynamic> map) {
    try {
      final id = _requireString(map, 'id');
      final title = _requireString(map, 'title');
      final content = _requireString(map, 'content');

      final rawTags = map['tags'];
      final tags = rawTags is List
          ? rawTags.map((e) => e.toString()).toList()
          : <String>[];

      final createdAt = _parseDate(map['createdAt'], 'createdAt');
      final updatedAt = _parseDate(map['updatedAt'], 'updatedAt');

      final isSynced = map['isSynced'] is bool
          ? map['isSynced'] as bool
          : false;

      final rawDeletedAt = map['deletedAt'];
      final deletedAt = rawDeletedAt == null
          ? null
          : _parseDate(rawDeletedAt, 'deletedAt');

      return Note(
        id: id,
        title: title,
        content: content,
        tags: tags,
        createdAt: createdAt,
        updatedAt: updatedAt,
        isSynced: isSynced,
        deletedAt: deletedAt,
      );
    } on NoteSerializationException {
      rethrow;
    } catch (e) {
      throw NoteSerializationException(
        'Échec inattendu lors de la désérialisation de la note',
        e,
      );
    }
  }

  // ---------------------------------------------------------------------
  // Sérialisation JSON
  // ---------------------------------------------------------------------
  //
  // Séparée de toMap/fromMap pour rester explicite si le format JSON doit
  // un jour diverger du format de stockage local (ex: si Hive stocke les
  // dates en int au lieu de String ISO8601).

  Map<String, dynamic> toJson() => toMap();

  factory Note.fromJson(Map<String, dynamic> json) => Note.fromMap(json);

  // ---------------------------------------------------------------------
  // Sérialisation Firestore
  // ---------------------------------------------------------------------

  /// On n'y stocke pas l'id : il correspond déjà à l'id du document
  /// Firestore lui-même (évite la duplication de la donnée).
  Map<String, dynamic> toFirestore() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  factory Note.fromFirestore(String id, Map<String, dynamic> data) {
    return Note.fromMap({...data, 'id': id});
  }

  // ---------------------------------------------------------------------
  // Helpers de validation
  // ---------------------------------------------------------------------

  static String _requireString(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) {
      throw NoteSerializationException('Champ requis manquant : "$key"');
    }
    if (value is! String || value.isEmpty) {
      throw NoteSerializationException(
        'Champ "$key" invalide : attendu une chaîne non vide, reçu $value '
        '(${value.runtimeType})',
      );
    }
    return value;
  }

  /// Parse une date depuis plusieurs formats possibles sans dépendre du
  /// package `cloud_firestore` :
  /// - déjà un [DateTime]
  /// - une chaîne ISO8601 (format local / JSON)
  /// - un `Timestamp` Firestore, détecté via duck-typing (présence d'une
  ///   méthode `toDate()`), sans avoir besoin de l'importer
  static DateTime _parseDate(dynamic value, String fieldName) {
    if (value == null) {
      throw NoteSerializationException('Champ requis manquant : "$fieldName"');
    }
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed == null) {
        throw NoteSerializationException(
          'Champ "$fieldName" invalide : date ISO8601 attendue, reçu "$value"',
        );
      }
      return parsed;
    }
    // Duck-typing pour un Timestamp Firestore (évite l'import direct de
    // cloud_firestore dans ce fichier).
    try {
      final dynamic dyn = value;
      final dynamic asDate = dyn.toDate();
      if (asDate is DateTime) return asDate;
    } catch (_) {
      // ce n'était pas un Timestamp-like, on tombe sur l'erreur ci-dessous
    }
    throw NoteSerializationException(
      'Champ "$fieldName" invalide : type non supporté ${value.runtimeType}',
    );
  }

  @override
  String toString() => 'Note(id: $id, title: $title, isSynced: $isSynced)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Note &&
        other.id == id &&
        other.title == title &&
        other.content == content &&
        _listEquals(other.tags, tags) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.isSynced == isSynced &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    content,
    Object.hashAll(tags),
    createdAt,
    updatedAt,
    isSynced,
    deletedAt,
  );

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
