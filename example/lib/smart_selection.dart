import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

class SmartSelectionExamplePage extends StatefulWidget {
  const SmartSelectionExamplePage({super.key});

  @override
  State<SmartSelectionExamplePage> createState() =>
      _SmartSelectionExamplePageState();
}

class _SmartSelectionExamplePageState extends State<SmartSelectionExamplePage> {
  static const _tag = 'example_smart_selection';
  static const _cities = ['London', 'Paris', 'Tokyo', 'Sydney', 'New York'];
  static final _ranges = {
    const Duration(hours: 1): 'Last hour',
    const Duration(days: 1): 'Last day',
    const Duration(days: 7): 'Last 7 days',
  };

  Duration _usageRange = const Duration(days: 7);
  late GlobalKey<DropdownSearchState<String>> _dropdownKey;
  late SmartSelectionProps<String> _smartProps;
  String? _selected;
  bool _clearing = false;
  bool _autoSelect = true;

  @override
  void initState() {
    super.initState();
    _resetDropdown();
  }

  void _resetDropdown() {
    // A new key simulates startup; ordinary rebuilds keep the same props/key.
    _dropdownKey = GlobalKey<DropdownSearchState<String>>();
    _smartProps = SmartSelectionProps<String>(
      tag: _tag,
      usageRange: _usageRange,
      autoSelect: _autoSelect,
      listBuilder: (context, items, selectItem) => items.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final item in items)
                  ActionChip(
                      key: ValueKey('smart-choice-$item'),
                      label: Text(item),
                      onPressed: () => selectItem(item)),
              ])),
      itemToString: (item) => item,
      itemFromString: (value) {
        if (!_cities.contains(value)) {
          throw const FormatException('Unknown city');
        }
        return value;
      },
    );
    _selected = null;
    final key = _dropdownKey;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || key != _dropdownKey) return;
      try {
        await key.currentState?.loadItems();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not load example choices.')));
        }
      }
    });
  }

  Future<void> _clearHistory({bool onlyOld = false}) async {
    setState(() => _clearing = true);
    try {
      await DropdownSearchCache.clearSmartSelection(
        tag: _tag,
        olderThan: onlyOld ? _usageRange : null,
      );
      if (!mounted) return;
      setState(_resetDropdown);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(onlyOld
            ? 'Old usage removed. Recent choices are preserved.'
            : 'Saved history cleared for this example.'),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not clear history. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Smart selection')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Learn a favorite destination',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  const Text(
                    'Select a city several times, then restart the dropdown. '
                    'Enable auto-selection to preselect the most-used city on restart. '
                    'The top three appear below the popup search bar even when '
                    'auto-selection is off.',
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    key: const ValueKey('smart-auto-select'),
                    title: const Text('Auto-select on startup'),
                    value: _autoSelect,
                    onChanged: _clearing
                        ? null
                        : (value) => setState(() {
                              _autoSelect = value;
                              _resetDropdown();
                            }),
                  ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Usage window',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Duration>(
                        key: const ValueKey('smart-usage-range'),
                        value: _usageRange,
                        isExpanded: true,
                        isDense: true,
                        items: _ranges.entries
                            .map((entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ))
                            .toList(),
                        onChanged: _clearing
                            ? null
                            : (range) {
                                if (range == null || range == _usageRange) {
                                  return;
                                }
                                setState(() {
                                  _usageRange = range;
                                  _resetDropdown();
                                });
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                      'Changing the window restarts the dropdown without '
                      'deleting any saved usage.'),
                  const SizedBox(height: 24),
                  DropdownSearch<String>(
                    key: _dropdownKey,
                    items: (_, __) => List.of(_cities),
                    smartSelectionProps: _smartProps,
                    itemsLoadMode: ItemsLoadMode.manual,
                    enabled: !_clearing,
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: 'Destination',
                        hintText: 'Choose a city',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    popupProps: const PopupProps.dialog(
                      showSearchBox: true,
                      searchDelay: Duration.zero,
                      showSelectedItems: true,
                    ),
                    onChanged: (value) {
                      if (mounted) setState(() => _selected = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text('Selected value: ${_selected ?? 'None'}',
                      key: const ValueKey('smart-selected-value'),
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed:
                            _clearing ? null : () => setState(_resetDropdown),
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Restart dropdown'),
                      ),
                      OutlinedButton(
                        onPressed: _clearing ? null : () => _clearHistory(),
                        child: const Text('Clear saved history'),
                      ),
                      OutlinedButton(
                        onPressed: _clearing
                            ? null
                            : () => _clearHistory(onlyOld: true),
                        child: const Text('Clear old usage'),
                      ),
                    ],
                  ),
                  if (_clearing) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 24),
                  const Text('History stays saved when you leave this page. '
                      'A tie or an empty usage window leaves the dropdown blank. '
                      'Restarting supplies no explicit selected value, so the '
                      'saved history can choose the initial value.'),
                  const SizedBox(height: 12),
                  const Text(
                      'Clear old usage keeps records within the selected '
                      'window. Both clear buttons affect only this example.'),
                  const SizedBox(height: 12),
                  const Text(
                      'This example preloads local choices so smart items '
                      'can be verified before the popup opens.'),
                ],
              ),
            ),
          ),
        ),
      );
}
