import 'dart:async';

/// Orders persistence operations across history writes and cache clearing.
/// Serialization applies to dropdowns in the current isolate.
class DropdownCacheStorage {
  static Future<void>? _pending;
  static int _smartGeneration = 0;
  static final Map<String, int> _smartTagGenerations = {};
  static final _smartChanges = StreamController<String?>.broadcast();

  static Stream<String?> get smartChanges => _smartChanges.stream;
  static void notifySmartChanged(String? tag) => _smartChanges.add(tag);

  static Future<T> run<T>(Future<T> Function() operation) {
    final previous = _pending;
    final result = Completer<T>();
    final done = Completer<void>();
    _pending = done.future;

    Future<void> execute() async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      } finally {
        // Release the queue before notifying callers, including across zones.
        if (identical(_pending, done.future)) _pending = null;
        done.complete();
      }
    }

    if (previous == null) {
      execute();
    } else {
      previous.then((_) => execute());
    }
    return result.future;
  }

  static int smartRevision(String tag) =>
      _smartGeneration + (_smartTagGenerations[tag] ?? 0);

  static void invalidateSmartSelection(String? tag) {
    if (tag == null) {
      _smartGeneration++;
    } else {
      _smartTagGenerations[tag] = (_smartTagGenerations[tag] ?? 0) + 1;
    }
  }
}
