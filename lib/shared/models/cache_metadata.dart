/// Cache metadata tracking last sync time per entity type.
class CacheMetadata {
  final String entityType;
  final DateTime lastSyncedAt;

  const CacheMetadata({
    required this.entityType,
    required this.lastSyncedAt,
  });

  Map<String, dynamic> toJson() => {
        'entity_type': entityType,
        'last_synced_at': lastSyncedAt.toIso8601String(),
      };

  factory CacheMetadata.fromJson(Map<String, dynamic> json) {
    return CacheMetadata(
      entityType: json['entity_type'] as String,
      lastSyncedAt: DateTime.parse(json['last_synced_at'] as String),
    );
  }
}
