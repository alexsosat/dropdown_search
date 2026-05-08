import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

class PinnedItemsProps<T> {
  /// Whether to show pinned items
  final bool showPinnedItems;

  /// Tag to save pinned items into local database
  final String pinnedItemsTag;

  /// Transformer to parse from a String to a T
  final PinnedItemsEntityTransformer<T> pinnedItemsEntityTransformer;

  /// Transformer to parse from a T to a String
  final PinnedItemsStringTransformer<T> pinnedItemsStringTransformer;

  /// scrollbar properties
  final ScrollProps scrollProps;

  /// alignment of the pinned items
  final MainAxisAlignment pinnedItemsAlignment;

  /// item click props
  final ClickProps itemClickProps;

  /// builder for the pinned items
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
