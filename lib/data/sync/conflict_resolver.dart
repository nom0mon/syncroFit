/// Resolves conflicts between local offline mutations and server-side data
/// using a last-write-wins strategy based on timestamps.
///
/// When a mutation is synced and the server record has been updated since the
/// local mutation was created, the conflict resolver determines which version
/// should prevail by comparing timestamps.
class ConflictResolver {
  /// Returns true if the local mutation should be applied (local wins).
  /// Returns false if the server version wins (local mutation discarded).
  ///
  /// The local mutation wins only if [localMutationTimestamp] is strictly
  /// after [serverUpdatedAt]. If the timestamps are equal or the server
  /// timestamp is newer, the server version wins.
  bool shouldApplyLocal({
    required DateTime localMutationTimestamp,
    required DateTime serverUpdatedAt,
  }) {
    return localMutationTimestamp.isAfter(serverUpdatedAt);
  }
}
