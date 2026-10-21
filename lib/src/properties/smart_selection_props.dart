import 'package:flutter/widgets.dart';

typedef SmartSelectionListBuilder<T> = Widget Function(
    BuildContext context, List<T> items, ValueChanged<T> selectItem);

/// Learns a single-selection dropdown's initial value from recent item taps.
///
/// Items sharing a [tag] share history. Identifiers must be stable and unique.
/// History is retained until cleared, including older usage. Complete original
/// item loads remove history for items that no longer exist in that collection.
class SmartSelectionProps<T> {
  final String tag;

  /// Rolling window used at startup, such as `Duration(days: 7)`.
  final Duration usageRange;

  /// Opt in to initial selection once original item loading verifies a winner.
  final bool autoSelect;

  /// Builds up to three verified items below the popup search bar.
  /// Items remain visible while searching; an empty history supplies an empty list.
  final SmartSelectionListBuilder<T>? listBuilder;

  final String Function(T item) itemToString;
  final T Function(String value) itemFromString;

  SmartSelectionProps({
    required this.tag,
    required this.usageRange,
    required this.itemToString,
    required this.itemFromString,
    this.autoSelect = false,
    this.listBuilder,
  }) {
    if (usageRange <= Duration.zero) {
      throw ArgumentError.value(usageRange, 'usageRange', 'Must be positive');
    }
  }
}
