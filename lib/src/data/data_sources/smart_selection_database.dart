import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'dropdown_cache_storage.dart';

class SmartSelectionUsage {
  final String id;
  final int count;
  final int lastUsed;
  SmartSelectionUsage(this.id, this.count, this.lastUsed);
}

/// Dated usage records, independent of item-provider and pinned-item caches.
class SmartSelectionDatabase {
  static const _prefix = 'dropdown_search:smart_selection:';

  Future<Map<String, List<Map<String, int>>>> _read(
      SharedPreferencesAsync prefs, String tag) async {
    final result = <String, List<Map<String, int>>>{};
    try {
      final stored = await prefs.getString('$_prefix$tag');
      if (stored == null) return result;
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, dynamic>) return result;
      for (final entry in decoded.entries) {
        if (entry.value is! List) continue;
        final records = <Map<String, int>>[];
        for (final record in entry.value as List) {
          if (record is! Map) continue;
          final at = record['at'];
          final count = record['count'];
          if (at is int && count is int && count > 0) {
            records.add({'at': at, 'count': count});
          }
        }
        if (records.isNotEmpty) result[entry.key] = records;
      }
    } on FormatException {
      // Invalid history is unavailable; the next tap starts valid history.
    } on TypeError {
      // Ignore a preference saved using an incompatible value type.
    }
    return result;
  }

  Future<void> recordClick({
    required String tag,
    required String item,
    DateTime? at,
  }) {
    final timestamp = (at ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
    return DropdownCacheStorage.run(() async {
      final prefs = SharedPreferencesAsync();
      final history = await _read(prefs, tag);
      final records = history.putIfAbsent(item, () => []);
      if (records.isNotEmpty && records.last['at'] == timestamp) {
        records.last['count'] = records.last['count']! + 1;
      } else {
        records.add({'at': timestamp, 'count': 1});
      }
      await prefs.setString('$_prefix$tag', jsonEncode(history));
      DropdownCacheStorage.notifySmartChanged(tag);
    });
  }

  /// Prunes missing IDs only when a complete source supplied [validItems].
  Future<List<SmartSelectionUsage>> ranked({
    required String tag,
    required Duration usageRange,
    Set<String>? validItems,
    bool Function()? isCurrent,
    DateTime? now,
  }) {
    if (usageRange <= Duration.zero) {
      throw ArgumentError.value(usageRange, 'usageRange', 'Must be positive');
    }
    final end = (now ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
    final start = end - usageRange.inMicroseconds;
    return DropdownCacheStorage.run(() async {
      final prefs = SharedPreferencesAsync();
      final history = await _read(prefs, tag);
      if (validItems != null && (isCurrent?.call() ?? true)) {
        final previousLength = history.length;
        history.removeWhere((id, _) => !validItems.contains(id));
        if (history.length != previousLength) {
          if (history.isEmpty) {
            await prefs.remove('$_prefix$tag');
          } else {
            await prefs.setString('$_prefix$tag', jsonEncode(history));
          }
          DropdownCacheStorage.notifySmartChanged(tag);
        }
      }
      final result = <SmartSelectionUsage>[];
      for (final entry in history.entries) {
        var count = 0;
        var lastUsed = start;
        for (final record in entry.value) {
          final at = record['at']!;
          if (at >= start && at <= end) {
            count += record['count']!;
            if (at > lastUsed) lastUsed = at;
          }
        }
        if (count > 0) {
          result.add(SmartSelectionUsage(entry.key, count, lastUsed));
        }
      }
      result.sort((a, b) {
        final countOrder = b.count.compareTo(a.count);
        if (countOrder != 0) return countOrder;
        final dateOrder = b.lastUsed.compareTo(a.lastUsed);
        return dateOrder != 0 ? dateOrder : a.id.compareTo(b.id);
      });
      return result;
    });
  }

  /// Returns a unique winner within the inclusive rolling interval.
  Future<String?> mostUsed({
    required String tag,
    required Duration usageRange,
    DateTime? now,
  }) {
    if (usageRange <= Duration.zero) {
      throw ArgumentError.value(usageRange, 'usageRange', 'Must be positive');
    }
    final end = (now ?? DateTime.now()).toUtc().microsecondsSinceEpoch;
    final start = end - usageRange.inMicroseconds;
    return DropdownCacheStorage.run(() async {
      final history = await _read(SharedPreferencesAsync(), tag);
      String? winner;
      var highest = 0;
      var tied = false;
      for (final entry in history.entries) {
        var count = 0;
        for (final record in entry.value) {
          if (record['at']! >= start && record['at']! <= end) {
            count += record['count']!;
          }
        }
        if (count > highest) {
          highest = count;
          winner = entry.key;
          tied = false;
        } else if (count > 0 && count == highest) {
          tied = true;
        }
      }
      return tied ? null : winner;
    });
  }

  Future<void> clear({String? tag, Duration? olderThan, DateTime? now}) {
    if (olderThan != null && olderThan <= Duration.zero) {
      throw ArgumentError.value(olderThan, 'olderThan', 'Must be positive');
    }
    final cutoff = olderThan == null
        ? null
        : (now ?? DateTime.now()).toUtc().microsecondsSinceEpoch -
            olderThan.inMicroseconds;
    DropdownCacheStorage.invalidateSmartSelection(tag);
    return DropdownCacheStorage.run(() async {
      final prefs = SharedPreferencesAsync();
      if (cutoff != null) {
        final tags = tag != null
            ? [tag]
            : (await prefs.getKeys())
                .where((key) => key.startsWith(_prefix))
                .map((key) => key.substring(_prefix.length));
        for (final historyTag in tags) {
          final history = await _read(prefs, historyTag);
          var changed = false;
          history.removeWhere((item, records) {
            final previousLength = records.length;
            records.removeWhere((record) => record['at']! < cutoff);
            changed = changed || records.length != previousLength;
            return records.isEmpty;
          });
          final key = '$_prefix$historyTag';
          if (history.isEmpty) {
            await prefs.remove(key);
            DropdownCacheStorage.notifySmartChanged(historyTag);
          } else if (changed) {
            await prefs.setString(key, jsonEncode(history));
            DropdownCacheStorage.notifySmartChanged(historyTag);
          }
        }
        return;
      }
      if (tag != null) {
        await prefs.remove('$_prefix$tag');
        DropdownCacheStorage.notifySmartChanged(tag);
      } else {
        final keys = await prefs.getKeys();
        final historyKeys =
            keys.where((key) => key.startsWith(_prefix)).toSet();
        if (historyKeys.isNotEmpty) await prefs.clear(allowList: historyKeys);
        DropdownCacheStorage.notifySmartChanged(null);
      }
    });
  }
}
