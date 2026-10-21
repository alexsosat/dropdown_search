import 'package:flutter/widgets.dart';

import 'properties/smart_selection_props.dart';

/// Original, unfiltered data shared by the field and its short-lived popup.
class DropdownSource<T> extends ChangeNotifier {
  List<T> items = const [];
  bool complete = false;
  bool completePrefix = false;
  bool hasData = false;
  int revision = 0;
  bool _disposed = false;

  void publish(List<T> data,
      {required bool complete, bool completePrefix = true}) {
    if (_disposed) return;
    items = List<T>.unmodifiable(data);
    this.complete = complete;
    this.completePrefix = completePrefix;
    hasData = true;
    revision++;
    notifyListeners();
  }

  void reset() {
    if (_disposed) return;
    items = List<T>.unmodifiable([]);
    complete = false;
    completePrefix = false;
    hasData = false;
    revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class SmartSelectionPresentation<T> {
  final List<T> items;
  final SmartSelectionListBuilder<T>? builder;

  SmartSelectionPresentation({required List<T> items, this.builder})
      : items = List<T>.unmodifiable(items);
}
