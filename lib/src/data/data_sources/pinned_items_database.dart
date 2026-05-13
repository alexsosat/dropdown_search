import 'package:shared_preferences/shared_preferences.dart';

/// Stores multiple pinned-items lists (as `List<String>`) keyed by a user tag.
///
/// Under the hood we use `SharedPreferences.setStringList`, and we keep a
/// small index of known tags to support listing/clearing all lists.
class PinnedItemsDatabase {
  static const String _prefix = 'dropdown_search:pinned_items:';
  static const String _tagsKey = '${_prefix}__tags';

  static SharedPreferencesWithCache? _prefs;

  /// Call once (e.g. app startup) to enable synchronous reads via [get].
  static Future<void> init() async {
    _prefs ??= await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
  }

  String _storageKey(String tag) => '$_prefix$tag';

  Future<void> addItem({
    required String tag,
    required String item,
    bool dedupe = true,
  }) async {
    await init();
    final prefs = _prefs!;
    final key = _storageKey(tag);
    final current = (prefs.getStringList(key) ?? const <String>[]).toList();

    if (!dedupe || !current.contains(item)) {
      current.add(item);
      await prefs.setStringList(key, current);
    }

    await _addTagToIndex(prefs, tag);
  }

  /// Deletes one [item] from the list stored under [tag].
  ///
  /// If the list becomes empty, the storage key is removed and the [tag] is
  /// removed from the internal tags index.
  Future<void> deleteItem({
    required String tag,
    required String item,
  }) async {
    await init();
    final prefs = _prefs!;
    final key = _storageKey(tag);
    final current = (prefs.getStringList(key) ?? const <String>[]).toList();

    final removed = current.remove(item);
    if (!removed) return;

    if (current.isEmpty) {
      await prefs.remove(key);
      await _removeTagFromIndex(prefs, tag);
    } else {
      await prefs.setStringList(key, current);
      await _addTagToIndex(prefs, tag);
    }
  }

  Future<void> save({
    required String tag,
    required List<String> items,
  }) async {
    await init();
    final prefs = _prefs!;
    await prefs.setStringList(_storageKey(tag), items);
    await _addTagToIndex(prefs, tag);
  }

  List<String> get(String tag) {
    final prefs = _prefs;
    assert(
      prefs != null,
      'PinnedItemsDatabase.init() must be called before using get()',
    );
    return prefs!.getStringList(_storageKey(tag)) ?? const <String>[];
  }

  Future<void> remove(String tag) async {
    await init();
    final prefs = _prefs!;
    await prefs.remove(_storageKey(tag));
    await _removeTagFromIndex(prefs, tag);
  }

  /// Returns all tags that have been saved via [save].
  Future<Set<String>> getTags() async {
    await init();
    final prefs = _prefs!;
    return (prefs.getStringList(_tagsKey) ?? const <String>[]).toSet();
  }

  /// Clears all pinned-item lists saved via this database.
  Future<void> clearAll() async {
    await init();
    final prefs = _prefs!;
    final tags = (prefs.getStringList(_tagsKey) ?? const <String>[]).toSet();
    for (final tag in tags) {
      await prefs.remove(_storageKey(tag));
    }
    await prefs.remove(_tagsKey);
  }

  Future<void> _addTagToIndex(
      SharedPreferencesWithCache prefs, String tag) async {
    final tags = (prefs.getStringList(_tagsKey) ?? const <String>[]).toSet();
    if (tags.add(tag)) {
      await prefs.setStringList(_tagsKey, tags.toList()..sort());
    }
  }

  Future<void> _removeTagFromIndex(
    SharedPreferencesWithCache prefs,
    String tag,
  ) async {
    final tags = (prefs.getStringList(_tagsKey) ?? const <String>[]).toSet();
    if (tags.remove(tag)) {
      if (tags.isEmpty) {
        await prefs.remove(_tagsKey);
      } else {
        await prefs.setStringList(_tagsKey, tags.toList()..sort());
      }
    }
  }
}
