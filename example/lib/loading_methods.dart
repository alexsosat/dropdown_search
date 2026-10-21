import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';

class LoadingMethodsExamplePage extends StatelessWidget {
  const LoadingMethodsExamplePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Loading methods')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Compare when items are fetched',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  const Text(
                      'Each dropdown has its own request counter and cache. '
                      'Requests use local data with a simulated 600 ms delay. '
                      'Open, close, and reopen each dropdown to compare the modes.'),
                  const SizedBox(height: 20),
                  const _LoadingModeCard(
                    key: ValueKey('loading-manual'),
                    mode: ItemsLoadMode.manual,
                    title: 'Manual',
                    description: 'Fetches only when you press Load / refresh. '
                        'Opening and searching use the loaded cache.',
                  ),
                  const SizedBox(height: 16),
                  const _LoadingModeCard(
                    key: ValueKey('loading-onOpen'),
                    mode: ItemsLoadMode.onOpen,
                    title: 'Every opening',
                    description: 'Fetches every time you open the dropdown. '
                        'Searching also makes a new request.',
                  ),
                  const SizedBox(height: 16),
                  const _LoadingModeCard(
                    key: ValueKey('loading-onFirstOpen'),
                    mode: ItemsLoadMode.onFirstOpen,
                    title: 'First opening',
                    description:
                        'Fetches on the first opening, then reuses the '
                        'cache when reopening or searching.',
                  ),
                  const SizedBox(height: 16),
                  const Text('Load / refresh explicitly fetches again in every '
                      'mode. These examples do not need an internet connection.'),
                ],
              ),
            ),
          ),
        ),
      );
}

class _LoadingModeCard extends StatefulWidget {
  final ItemsLoadMode mode;
  final String title;
  final String description;

  const _LoadingModeCard({
    super.key,
    required this.mode,
    required this.title,
    required this.description,
  });

  @override
  State<_LoadingModeCard> createState() => _LoadingModeCardState();
}

class _LoadingModeCardState extends State<_LoadingModeCard> {
  static const _cities = ['London', 'Paris', 'Tokyo', 'Sydney', 'New York'];
  final _dropdownKey = GlobalKey<DropdownSearchState<String>>();
  int _requests = 0;
  int _activeRequests = 0;
  bool get _loading => _activeRequests > 0;
  String _status = 'Not loaded';

  Future<List<String>> _fetchItems(String filter, LoadProps? loadProps) async {
    if (mounted) {
      setState(() {
        _requests++;
        _activeRequests++;
        _status = 'Loading…';
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final items = _cities
        .where((city) => city.toLowerCase().contains(filter.toLowerCase()))
        .toList();
    if (mounted) {
      setState(() {
        _activeRequests--;
        _status = 'Loaded ${items.length} choices';
      });
    }
    return items;
  }

  Future<void> _refresh() async {
    try {
      await _dropdownKey.currentState!.loadItems();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeRequests = 0;
        _status = 'Load failed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not load choices. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(widget.description),
              const SizedBox(height: 16),
              DropdownSearch<String>(
                key: _dropdownKey,
                itemsLoadMode: widget.mode,
                items: _fetchItems,
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
                  emptyBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        widget.mode == ItemsLoadMode.manual && _requests == 0
                            ? 'Use Load / refresh to fetch choices first.'
                            : 'No matching choices.'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Requests: $_requests',
                  key: ValueKey('requests-${widget.mode.name}')),
              const SizedBox(height: 4),
              Text(_loading ? 'Loading…' : _status,
                  key: ValueKey('status-${widget.mode.name}')),
              if (_loading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: ValueKey('refresh-${widget.mode.name}'),
                  onPressed: _loading ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Load / refresh'),
                ),
              ),
            ],
          ),
        ),
      );
}
