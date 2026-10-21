// @dart=3.0

import 'dart:async';

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/types.dart';

/// In-memory persistence with controllable failures and delayed smart reads.
final class HistoryPreferences extends InMemorySharedPreferencesAsync {
  HistoryPreferences() : super.empty();

  bool failReads = false;
  bool failWrites = false;
  bool failSmartClear = false;
  Completer<void>? readGate;
  Completer<void>? readStarted;

  @override
  Future<String?> getString(
      String key, SharedPreferencesOptions options) async {
    readStarted?.complete();
    readStarted = null;
    final gate = readGate;
    if (gate != null) await gate.future;
    if (failReads) throw StateError('Preferences read failed');
    return super.getString(key, options);
  }

  @override
  Future<bool> setString(
      String key, String value, SharedPreferencesOptions options) {
    if (failWrites) return Future.error(StateError('Preferences write failed'));
    return super.setString(key, value, options);
  }

  @override
  Future<bool> clear(
      ClearPreferencesParameters parameters, SharedPreferencesOptions options) {
    if (failSmartClear &&
        parameters.filter.allowList!
            .any((key) => key.startsWith('dropdown_search:smart_selection:'))) {
      return Future.error(StateError('Preferences clear failed'));
    }
    return super.clear(parameters, options);
  }
}
