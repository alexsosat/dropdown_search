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
              clickProps: ClickProps(
                autoSelectIfOnlyOne: true,
                autoSelectIfOnlyOneOnSearch: true,
              ),
              popupProps: PopupProps.modalBottomSheet(
                showSearchBox: true,
                cacheItems: true,
                searchDelay: const Duration(seconds: 0),
                itemClickProps: ClickProps(
                  autoSelectIfOnlyOne: true,
                  autoSelectIfOnlyOneOnSearch: true,
                ),
                pinnedItemsProps: PinnedItemsProps(
                  pinnedItemsTag: 'example_pinned_items',
                  pinnedItemsEntityTransformer: (item) => int.parse(item),
                  pinnedItemsStringTransformer: (item) => item.toString(),
                  showPinnedItems: true,
                ),
              ),
            ),
            DropdownSearch<String>(
              items: (filter, t) async {
                await Future.delayed(Duration(seconds: 2));

                return ['Item 1'];
              },
              popupProps: PopupProps.modalBottomSheet(
                disabledItemFn: (item) => item == 'Item 1',
                itemClickProps: ClickProps(
                  autoSelectIfOnlyOne: true,
                ),
                itemProps: ItemProps(
                  title: (item) => Text(item + "A"),
                  leading: (item) => Icon(Icons.wordpress),
                  subtitle: (item) => Text(item + "B"),
                ),
                pinnedItemsProps: PinnedItemsProps(
                  pinnedItemsTag: 'example_pinned_items_2',
                  pinnedItemsEntityTransformer: (item) => item,
                  pinnedItemsStringTransformer: (item) => item,
                  showPinnedItems: true,
                ),
              ),
            ),
          ],
        ),
      );
}
