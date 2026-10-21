import 'data/data_sources/pinned_items_database.dart';
import 'data/data_sources/smart_selection_database.dart';

/// Clears persisted dropdown history without changing current selections.
///
/// Omit [tag] to clear every tag. Item-provider caches and unrelated shared
/// preferences are preserved. Open popups keep their currently displayed pins;
/// reopening them loads the cleared history.
class DropdownSearchCache {
  /// With [olderThan], removes only usage strictly older than that duration.
  /// The duration must be positive; usage at the cutoff is preserved.
  static Future<void> clearSmartSelection({
    String? tag,
    Duration? olderThan,
  }) =>
      SmartSelectionDatabase().clear(tag: tag, olderThan: olderThan);

  static Future<void> clearPinnedItems({String? tag}) => tag == null
      ? PinnedItemsDatabase().clearAll()
      : PinnedItemsDatabase().remove(tag);

  /// Clears the matching tag in both namespaces, or every tag if omitted.
  /// With [olderThan], only expired smart-selection usage is removed; pins
  /// have no expiration date and are preserved. Otherwise both clears are
  /// attempted. Failures are returned through the future.
  static Future<void> clearAll({String? tag, Duration? olderThan}) async {
    if (olderThan != null) {
      await clearSmartSelection(tag: tag, olderThan: olderThan);
      return;
    }
    await Future.wait([
      clearSmartSelection(tag: tag),
      clearPinnedItems(tag: tag),
    ]);
  }
}
