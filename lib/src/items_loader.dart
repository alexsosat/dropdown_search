import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import 'properties/items_load_mode.dart';
import 'dropdown_source.dart';

/// Loading state owned by the dropdown rather than its short-lived popup.
class ItemsLoader<T> extends ChangeNotifier {
  final FutureOr<List<T>> Function() _load;
  ItemsLoadMode mode;
  List<T> items = [];
  bool hasLoaded = false;
  bool isLoading = false;
  Object? error;
  StackTrace? stackTrace;
  int revision = 0;
  int _generation = 0;
  bool _disposed = false;
  Future<List<T>>? _pending;

  ItemsLoader(this._load, this.mode);

  int get generation => _generation;

  Future<List<T>> load() {
    if (_disposed) {
      return Future.error(StateError('The dropdown has been disposed'));
    }
    final pending = _pending;
    if (pending != null) return pending.then(List<T>.of);

    final completer = Completer<List<T>>();
    final generation = _generation;
    _pending = completer.future;
    isLoading = true;
    error = null;
    stackTrace = null;
    notifyListeners();

    // Future.sync also captures exceptions from synchronous item providers.
    Future<List<T>>.sync(_load).then((data) {
      final result = List<T>.of(data);
      if (!_disposed && generation == _generation) {
        items = List<T>.of(result);
        hasLoaded = true;
        revision++;
        _finish();
      }
      completer.complete(result);
    }, onError: (Object failure, StackTrace trace) {
      if (!_disposed && generation == _generation) {
        error = failure;
        stackTrace = trace;
        _finish();
      }
      completer.completeError(failure, trace);
    });
    return completer.future.then(List<T>.of);
  }

  void _finish() {
    _pending = null;
    isLoading = false;
    notifyListeners();
  }

  void reset(ItemsLoadMode newMode) {
    _generation++;
    mode = newMode;
    _pending = null;
    items = [];
    hasLoaded = false;
    isLoading = false;
    error = null;
    stackTrace = null;
    revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

/// Connects the popup to its owner's source, selection and shortcut state.
class ItemsLoaderScope<T> extends InheritedWidget {
  final ItemsLoader<T> loader;
  final DropdownSource<T>? source;
  final ValueListenable<SmartSelectionPresentation<T>>? smartSelection;
  final ValueListenable<List<T>>? selectedItems;
  final ValueListenable<List<T>>? suggestedItems;
  final bool Function()? isEnabled;
  final bool Function(T item)? canSelect;

  const ItemsLoaderScope({
    super.key,
    required this.loader,
    this.source,
    this.smartSelection,
    this.selectedItems,
    this.suggestedItems,
    this.isEnabled,
    this.canSelect,
    required super.child,
  });

  @override
  bool updateShouldNotify(ItemsLoaderScope<T> oldWidget) =>
      oldWidget.loader != loader;
}
