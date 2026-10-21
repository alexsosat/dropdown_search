import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

class PinnedItemsExamplePage extends StatefulWidget {
  const PinnedItemsExamplePage({super.key});

  @override
  State<PinnedItemsExamplePage> createState() => _PinnedItemsExamplePageState();
}

class _PinnedItemsExamplePageState extends State<PinnedItemsExamplePage> {
  static const _tag = 'example_pinned_items_page';
  static const _cities = ['London', 'Paris', 'Tokyo', 'Sydney', 'New York'];
  GlobalKey<DropdownSearchState<String>> _dropdownKey = GlobalKey();
  String? _selected;
  bool _clearing = false;

  void _restart() {
    _dropdownKey = GlobalKey<DropdownSearchState<String>>();
    _selected = null;
  }

  Future<void> _clearPins() async {
    setState(() => _clearing = true);
    try {
      await DropdownSearchCache.clearPinnedItems(tag: _tag);
      if (!mounted) return;
      setState(_restart);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Saved pins cleared for this example.')),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
              content: Text('Could not clear pins. Please try again.')),
        );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pinned items')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Keep destinations at the top',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  const Text(
                    'Open the dropdown and tap a star to pin a city. '
                    'Pinned cities move to the top of the same list in the '
                    'order you pinned them. Tap the star again to unpin.',
                  ),
                  const SizedBox(height: 24),
                  DropdownSearch<String>(
                    key: _dropdownKey,
                    enabled: !_clearing,
                    items: (_, __) => List.of(_cities),
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: 'Destination',
                        hintText: 'Choose a city',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    popupProps: PopupProps.dialog(
                      showSearchBox: true,
                      searchDelay: Duration.zero,
                      cacheItems: true,
                      showSelectedItems: true,
                      itemClickProps: const ClickProps(ignorePointers: false),
                      pinnedItemsProps: PinnedItemsProps(
                        showPinnedItems: true,
                        pinnedItemsTag: _tag,
                        pinnedItemsEntityTransformer: (value) => value,
                        pinnedItemsStringTransformer: (item) => item,
                      ),
                      itemBuilder:
                          (context, item, disabled, selected, pinned) =>
                              ListTile(
                        key: ValueKey('pinned-city-$item'),
                        enabled: !disabled,
                        selected: selected,
                        tileColor: pinned
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : null,
                        title: Text(item),
                        subtitle: pinned ? const Text('Pinned') : null,
                        trailing: IconButton(
                          tooltip: '${pinned ? 'Unpin' : 'Pin'} $item',
                          icon: Icon(pinned ? Icons.star : Icons.star_border),
                          onPressed: disabled
                              ? null
                              : () {
                                  final dropdown = _dropdownKey.currentState;
                                  if (pinned) {
                                    dropdown?.popupRemovePinnedItem(item);
                                  } else {
                                    dropdown?.popupAddPinnedItem(item);
                                  }
                                },
                        ),
                      ),
                    ),
                    onChanged: (value) => setState(() => _selected = value),
                  ),
                  const SizedBox(height: 16),
                  Text('Selected value: ${_selected ?? 'None'}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 20),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    FilledButton.icon(
                      onPressed: _clearing ? null : () => setState(_restart),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Restart dropdown'),
                    ),
                    OutlinedButton(
                      onPressed: _clearing ? null : _clearPins,
                      child: const Text('Clear saved pins'),
                    ),
                  ]),
                  if (_clearing) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Search still filters pinned cities. Clear the search to '
                    'see hidden pins again. Unpinned cities return to their '
                    'original positions.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Restart the dropdown or leave and revisit this page to '
                    'see saved pins restored. Restart resets the selection. '
                    'Clear saved pins affects only this example. '
                    'All choices are local; no internet connection is needed.',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
