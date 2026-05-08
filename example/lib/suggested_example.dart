import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

class SuggestedExample extends StatefulWidget {
  const SuggestedExample({super.key});

  @override
  State<SuggestedExample> createState() => _SuggestedExampleState();
}

class _SuggestedExampleState extends State<SuggestedExample> {
  late GlobalKey<DropdownSearchState<int>> _dropdownSearchKey;

  @override
  void initState() {
    super.initState();
    _dropdownSearchKey = GlobalKey<DropdownSearchState<int>>();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text("Suggested Example")),
        body: Column(
          children: [
            DropdownSearch<int>(
              key: _dropdownSearchKey,
              items: (filter, t) => [1, 2, 3, 4, 5, 6, 7],
              popupProps: PopupProps.modalBottomSheet(
                pinnedItemsProps: PinnedItemsProps(
                  pinnedItemsTag: 'example_pinned_items',
                  pinnedItemsEntityTransformer: (item) => int.parse(item),
                  pinnedItemsStringTransformer: (item) => item.toString(),
                  showPinnedItems: true,
                ),
              ),
            ),
          ],
        ),
      );
}
