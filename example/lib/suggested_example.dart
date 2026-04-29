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
                ignorePointers: false,
              ),
              popupProps: PopupProps.modalBottomSheet(
                suggestedItemProps: SuggestedItemProps(
                  showSuggestedItems: true,
                  suggestedItems: (items) =>
                      items.where((e) => e % 2 == 0).toList(),
                ),
                itemBuilder:
                    (context, item, isDisabled, isSelected, isSuggested) =>
                        ListTile(
                  title: Text(item.toString()),
                  trailing: isSelected
                      ? Icon(Icons.check)
                      : isSuggested
                          ? ElevatedButton(
                              onPressed: () => _dropdownSearchKey.currentState
                                  ?.popupRemoveSuggestedItem(item),
                              child: Icon(Icons.star))
                          : ElevatedButton(
                              onPressed: () => _dropdownSearchKey.currentState
                                  ?.popupAddSuggestedItem(item),
                              child: Icon(Icons.star_border),
                            ),
                ),
              ),
            ),
          ],
        ),
      );
}
