class Folder {
  const Folder({
    this.id,
    required this.name,
    required this.createdAt,
    this.cardCount = 0,
  });
  final int? id;
  final String name, createdAt;
  final int cardCount;
  factory Folder.fromMap(Map<String, Object?> m) => Folder(
    id: m['id'] as int,
    name: m['name'] as String,
    createdAt: m['created_at'] as String,
    cardCount: (m['card_count'] as int?) ?? 0,
  );
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'name': name.trim(),
    'created_at': createdAt,
  };
}

class CardRecord {
  static const suits = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];
  const CardRecord({
    this.id,
    required this.title,
    required this.suit,
    required this.folderId,
    this.notes = '',
    this.imageRef,
  });
  final int? id;
  final int folderId;
  final String title, suit, notes;
  final String? imageRef;
  String get symbol =>
      {'Hearts': '♥', 'Diamonds': '♦', 'Clubs': '♣', 'Spades': '♠'}[suit] ??
      '?';
  factory CardRecord.fromMap(Map<String, Object?> m) => CardRecord(
    id: m['id'] as int,
    title: m['title'] as String,
    suit: m['suit'] as String,
    folderId: m['folder_id'] as int,
    notes: m['notes'] as String,
    imageRef: m['image_ref'] as String?,
  );
  Map<String, Object?> toMap() => {
    if (id != null) 'id': id,
    'title': title.trim(),
    'suit': suit,
    'folder_id': folderId,
    'notes': notes,
    'image_ref': imageRef?.trim().isEmpty == true ? null : imageRef?.trim(),
  };
}
