import 'dart:convert';

/// Status of a queued sync mutation.
enum SyncStatus { pending, inProgress, failed }

/// Represents a mutation queued for sync with the backend.
class SyncMutation {
  final String id;
  final String
      entityType; // 'exercise', 'workout', 'profile', 'workout_history'
  final String entityId;
  final String operationType; // 'create', 'update', 'delete'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int retryCount;
  final SyncStatus status;

  const SyncMutation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operationType,
    required this.payload,
    required this.createdAt,
    this.retryCount = 0,
    this.status = SyncStatus.pending,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation_type': operationType,
        'payload': jsonEncode(payload),
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
        'status': status.name,
      };

  factory SyncMutation.fromJson(Map<String, dynamic> json) {
    return SyncMutation(
      id: json['id'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as String,
      operationType: json['operation_type'] as String,
      payload: json['payload'] is String
          ? jsonDecode(json['payload'] as String) as Map<String, dynamic>
          : json['payload'] as Map<String, dynamic>,
      createdAt: DateTime.parse(json['created_at'] as String),
      retryCount: json['retry_count'] as int? ?? 0,
      status: SyncStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SyncStatus.pending,
      ),
    );
  }

  SyncMutation copyWith({
    String? id,
    String? entityType,
    String? entityId,
    String? operationType,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    int? retryCount,
    SyncStatus? status,
  }) {
    return SyncMutation(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operationType: operationType ?? this.operationType,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
      status: status ?? this.status,
    );
  }
}
