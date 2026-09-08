/// Modèle de données représentant une note Markdown.
///
/// Sert de contrat partagé pour toute l'équipe :
/// - `Benit` l'utilise pour la persistance locale (Hive)
/// - `Check` / `Ouattara` l'utilisent pour la sync Firestore
class Note {
  final String id;
  final String title;
  final String content; // contenu au format Markdown
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced; // true si la version locale est synchronisée avec Firestore

  const Note({
    required this.id,
    required this.title,
    required this.content,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
  });

  /// Crée une copie de la note avec certains champs modifiés.
  Note copyWith({
    String? id,
    String? title,
    String? content,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Sérialisation générique (utilisée pour Hive, cache local, debug...).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isSynced': isSynced,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      tags: List<String>.from(map['tags'] as List? ?? []),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      isSynced: map['isSynced'] as bool? ?? false,
    );
  }

  /// Sérialisation JSON (identique à toMap/fromMap ici, mais séparée
  /// pour rester explicite si le format JSON doit un jour diverger
  /// du format de stockage local).
  Map<String, dynamic> toJson() => toMap();

  factory Note.fromJson(Map<String, dynamic> json) => Note.fromMap(json);

  /// Sérialisation spécifique Firestore : on n'y stocke pas l'id
  /// (il correspond déjà à l'id du document Firestore lui-même).
  Map<String, dynamic> toFirestore() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  factory Note.fromFirestore(String id, Map<String, dynamic> data) {
    return Note.fromMap({...data, 'id': id});
  }

  @override
  String toString() => 'Note(id: $id, title: $title, isSynced: $isSynced)';
}
