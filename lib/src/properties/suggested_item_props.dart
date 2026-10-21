import 'package:flutter/material.dart';

import '../../dropdown_search.dart';

class SuggestedItemProps<T> {
  /// Show suggested shortcuts below the field from the first frame.
  final bool showSuggestedItems;

  ///to customize favorites chips
  final FavoriteItemsBuilder<T>? suggestedItemBuilder;

  /// Independent suggestions, available without loading dropdown items.
  final List<T> suggestedItems;

  ///favorite items alignment
  final MainAxisAlignment suggestedItemsAlignment;

  final ClickProps itemClickProps;

  final ScrollProps scrollProps;

  const SuggestedItemProps({
    this.suggestedItemBuilder,
    this.suggestedItems = const [],
    this.suggestedItemsAlignment = MainAxisAlignment.start,
    this.showSuggestedItems = false,
    this.itemClickProps = const ClickProps(),
    this.scrollProps = const ScrollProps(scrollDirection: Axis.horizontal),
  });
}
