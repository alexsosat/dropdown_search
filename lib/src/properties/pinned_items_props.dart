import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

class PinnedItemsProps<T> {
  /// Whether to move pinned rows to the start of the main list.
  /// Rows follow the normal search filter and appear in oldest-pin-first order.
  final bool showPinnedItems;

  /// Tag to save pinned items into local database
  final String pinnedItemsTag;

  /// Transformer to parse from a String to a T
  final PinnedItemsEntityTransformer<T> pinnedItemsEntityTransformer;

  /// Transformer to parse from a T to a String
  final PinnedItemsStringTransformer<T> pinnedItemsStringTransformer;

  /// Obsolete horizontal-section setting, retained for compatibility.
  /// Pinned rows use [PopupProps.listViewProps] and [PopupProps.scrollbarProps].
  final ScrollProps scrollProps;

  /// Obsolete horizontal-section alignment, retained for compatibility.
  final MainAxisAlignment pinnedItemsAlignment;

  /// Obsolete horizontal-section click settings, retained for compatibility.
  /// Pinned rows use [PopupProps.itemClickProps].
  final ClickProps itemClickProps;

  /// Obsolete horizontal-section builder, retained for compatibility.
  /// Use [PopupProps.itemBuilder] and its `isPinned` argument to customize rows.
  final FavoriteItemsBuilder<T>? pinnedItemsBuilder;

  const PinnedItemsProps({
    this.showPinnedItems = false,
    required this.pinnedItemsTag,
    required this.pinnedItemsEntityTransformer,
    required this.pinnedItemsStringTransformer,
    this.scrollProps = const ScrollProps(scrollDirection: Axis.horizontal),
    this.pinnedItemsAlignment = MainAxisAlignment.start,
    this.itemClickProps = const ClickProps(),
    this.pinnedItemsBuilder,
  });
}
