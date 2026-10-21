import 'dart:async';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:dropdown_search/src/data/data_sources/pinned_items_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

// Exercise the repository's example without making it a package dependency.
// ignore: avoid_relative_lib_imports
import '../example/lib/suggested_example.dart';

const _tag = 'pinned-items-test';
final _database = PinnedItemsDatabase();

PinnedItemsProps<int> _pinProps({bool enabled = true}) => PinnedItemsProps(
      showPinnedItems: enabled,
      pinnedItemsTag: _tag,
      pinnedItemsEntityTransformer: int.parse,
      pinnedItemsStringTransformer: (item) => item.toString(),
    );

Future<void> _mountPopup(WidgetTester tester, Widget popup) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 350, height: 500, child: popup)),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _showIntPopup(
  WidgetTester tester, {
  GlobalKey<DropdownSearchPopupState<int>>? popupKey,
  List<int> items = const [1, 2, 3, 4],
  bool enabled = true,
  bool cacheItems = true,
  bool multiSelection = false,
  List<int> selectedItems = const [],
  DropdownSearchPopupItemEnabled<int>? disabledItemFn,
  ValueChanged<List<int>>? onItemsLoaded,
  TextEditingController? searchController,
}) =>
    _mountPopup(
      tester,
      DropdownSearchPopup<int>(
        key: popupKey,
        items: (filter, loadProps) => List.of(items),
        isMultiSelectionMode: multiSelection,
        defaultSelectedItems: selectedItems,
        popupProps: PopupPropsMultiSelection.dialog(
          showSearchBox: true,
          searchDelay: Duration.zero,
          searchFieldProps: TextFieldProps(controller: searchController),
          cacheItems: cacheItems,
          pinnedItemsProps: _pinProps(enabled: enabled),
          disabledItemFn: disabledItemFn,
          onItemsLoaded: onItemsLoaded,
        ),
      ),
    );

List<String> _rowOrder(WidgetTester tester) => tester
    .widgetList<ListTile>(find.byType(ListTile))
    .map((tile) => (tile.title! as Text).data!)
    .toList();

Finder _pinButton(int item) => find.descendant(
      of: find.widgetWithText(ListTile, '$item'),
      matching: find.byType(IconButton),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await PinnedItemsDatabase.init();
  });

  setUp(() async => _database.clearAll());

  for (final mode in [ItemsLoadMode.manual, ItemsLoadMode.onFirstOpen]) {
    testWidgets('cached loading preserves pin ordering and search with $mode',
        (tester) async {
      await _database.save(tag: _tag, items: ['3', '1']);
      final key = GlobalKey<DropdownSearchState<int>>();
      var calls = 0;
      await _mountPopup(
        tester,
        DropdownSearch<int>(
          key: key,
          itemsLoadMode: mode,
          items: (_, __) {
            calls++;
            return [1, 2, 3, 4];
          },
          popupProps: PopupProps.dialog(
            showSearchBox: true,
            searchDelay: Duration.zero,
            pinnedItemsProps: _pinProps(),
          ),
        ),
      );
      if (mode == ItemsLoadMode.manual) await key.currentState!.loadItems();
      key.currentState!.openDropDownSearch();
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['3', '1', '2', '4']);
      expect(key.currentState!.popupGetItems, [1, 2, 3, 4]);
      await tester.enterText(find.byType(TextField), '2');
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['2']);
      await key.currentState!.loadItems();
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['2']);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['3', '1', '2', '4']);
      await tester.tap(_pinButton(3));
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['1', '2', '3', '4']);
      key.currentState!.closeDropDownSearch();
      await tester.pumpAndSettle();
      key.currentState!.openDropDownSearch();
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['1', '2', '3', '4']);
      expect(calls, 2);
    });
  }

  testWidgets('saved pins share the main list in oldest-pin-first order',
      (tester) async {
    await _database.save(tag: _tag, items: ['3', '1']);
    final key = GlobalKey<DropdownSearchPopupState<int>>();
    final loaded = <List<int>>[];
    await _showIntPopup(tester,
        popupKey: key, onItemsLoaded: (items) => loaded.add(List.of(items)));

    expect(_rowOrder(tester), ['3', '1', '2', '4']);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('3'), findsOneWidget);
    expect(key.currentState!.getLoadedItems, [1, 2, 3, 4]);
    expect(loaded, [
      [1, 2, 3, 4]
    ]);
  });

  testWidgets('pin and unpin reorder immediately and restore source positions',
      (tester) async {
    final key = GlobalKey<DropdownSearchPopupState<int>>();
    await _showIntPopup(tester, popupKey: key);

    await tester.tap(_pinButton(3));
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['3', '1', '2', '4']);
    await tester.tap(_pinButton(1));
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['3', '1', '2', '4']);

    key.currentState!.addPinnedItem(3);
    await tester.pumpAndSettle();
    expect(key.currentState!.pinnedItems, [3, 1]);
    expect(_database.get(_tag), ['3', '1']);

    await tester.tap(_pinButton(3));
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['1', '2', '3', '4']);
    await tester.tap(_pinButton(3));
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['1', '3', '2', '4']);
    expect(_database.get(_tag), ['1', '3']);
    await tester.tap(_pinButton(1));
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['3', '1', '2', '4']);

    await tester.pumpWidget(const SizedBox.shrink());
    await _showIntPopup(tester);
    expect(_rowOrder(tester), ['3', '1', '2', '4']);
  });

  for (final cacheItems in [true, false]) {
    testWidgets('search preserves hidden pins with cacheItems=$cacheItems',
        (tester) async {
      await _database.save(tag: _tag, items: ['3', '1']);
      final controller = TextEditingController(text: '2');
      addTearDown(controller.dispose);
      await _showIntPopup(tester,
          cacheItems: cacheItems, searchController: controller);
      expect(_rowOrder(tester), ['2']);
      expect(_database.get(_tag), ['3', '1']);

      await tester.enterText(find.byType(TextField), '9');
      await tester.pumpAndSettle();
      expect(find.text('No data found'), findsOneWidget);
      expect(_database.get(_tag), ['3', '1']);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['3', '1', '2', '4']);
    });
  }

  testWidgets('pins remain saved when results are empty or missing an item',
      (tester) async {
    await _database.save(tag: _tag, items: ['3']);
    await _showIntPopup(tester, items: []);
    expect(find.text('No data found'), findsOneWidget);
    expect(_database.get(_tag), ['3']);
    await tester.pumpWidget(const SizedBox.shrink());
    await _showIntPopup(tester, items: [1, 2]);
    expect(_rowOrder(tester), ['1', '2']);
    expect(_database.get(_tag), ['3']);
  });

  testWidgets('disabled rows cannot be pinned or moved to the top',
      (tester) async {
    await _database.save(tag: _tag, items: ['3', '4']);
    final key = GlobalKey<DropdownSearchPopupState<int>>();
    await _showIntPopup(tester,
        popupKey: key, disabledItemFn: (item) => item == 3);
    expect(_rowOrder(tester), ['4', '1', '2', '3']);
    expect(tester.widget<IconButton>(_pinButton(3)).onPressed, isNull);
    key.currentState!.addPinnedItem(3);
    await tester.pumpAndSettle();
    expect(key.currentState!.pinnedItems, [4]);
    expect(_database.get(_tag), ['3', '4']);
  });

  testWidgets('disabled pinning preserves ordinary list order', (tester) async {
    await _database.save(tag: _tag, items: ['3']);
    final key = GlobalKey<DropdownSearchPopupState<int>>();
    await _showIntPopup(tester, enabled: false, popupKey: key);
    key.currentState!.addPinnedItem(4);
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['1', '2', '3', '4']);
    expect(find.byIcon(Icons.star_border), findsNothing);
    expect(_database.get(_tag), ['3']);
  });

  testWidgets('compareFn matches saved pins and renders loaded objects',
      (tester) async {
    await _database.save(tag: _tag, items: ['3', '3']);
    final items = [const _Item(1, 'One'), const _Item(3, 'Three')];
    final key = GlobalKey<DropdownSearchPopupState<_Item>>();
    final rendered = <int, _Item>{};
    final pinnedStatus = <int, bool>{};
    await _mountPopup(
      tester,
      DropdownSearchPopup<_Item>(
        key: key,
        items: (filter, loadProps) => items,
        compareFn: (a, b) => a.id == b.id,
        popupProps: PopupPropsMultiSelection.dialog(
          pinnedItemsProps: PinnedItemsProps(
            showPinnedItems: true,
            pinnedItemsTag: _tag,
            pinnedItemsEntityTransformer: (value) =>
                _Item(int.parse(value), 'Saved'),
            pinnedItemsStringTransformer: (item) => '${item.id}',
          ),
          itemBuilder: (context, item, disabled, selected, pinned) {
            rendered[item.id] = item;
            pinnedStatus[item.id] = pinned;
            return ListTile(title: Text(item.label));
          },
        ),
      ),
    );
    expect(_rowOrder(tester), ['Three', 'One']);
    expect(rendered[3], same(items[1]));
    expect(pinnedStatus, {1: false, 3: true});
    expect(key.currentState!.pinnedItems, hasLength(1));
    key.currentState!.addPinnedItem(const _Item(3, 'Duplicate'));
    await tester.pumpAndSettle();
    expect(key.currentState!.pinnedItems, hasLength(1));
    key.currentState!.removePinnedItem(const _Item(3, 'Equivalent'));
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['One', 'Three']);
    expect(pinnedStatus[3], isFalse);
  });

  testWidgets('later pages promote saved pins without changing page offsets',
      (tester) async {
    await _database.save(tag: _tag, items: ['5', '3']);
    final offsets = <int>[];
    final pinsAtLoad = <List<String>>[];
    await _mountPopup(
      tester,
      DropdownSearchPopup<int>(
        items: (filter, loadProps) {
          offsets.add(loadProps!.skip);
          return [1, 2, 3, 4, 5]
              .skip(loadProps.skip)
              .take(loadProps.take)
              .toList();
        },
        popupProps: PopupPropsMultiSelection.dialog(
          disableFilter: true,
          pinnedItemsProps: _pinProps(),
          infiniteScrollProps: const InfiniteScrollProps(
            loadProps: LoadProps(take: 2),
          ),
          onItemsLoaded: (_) => pinsAtLoad.add(_database.get(_tag)),
        ),
      ),
    );
    expect(offsets, [0, 2, 4]);
    expect(pinsAtLoad, everyElement(['5', '3']));
    expect(_rowOrder(tester), ['5', '3', '1', '2', '4']);
  });

  testWidgets('multi-selection stays attached to the correct reordered row',
      (tester) async {
    await _database.save(tag: _tag, items: ['3']);
    final key = GlobalKey<DropdownSearchPopupState<int>>();
    await _showIntPopup(tester,
        popupKey: key, multiSelection: true, selectedItems: [2]);
    expect(_rowOrder(tester), ['3', '1', '2', '4']);
    await tester.tap(find
        .ancestor(of: find.text('3'), matching: find.byType(InkResponse))
        .last);
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem, [2, 3]);
    key.currentState!.removePinnedItem(3);
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['1', '2', '3', '4']);
    expect(
        tester.widgetList<Checkbox>(find.byType(Checkbox)).map((c) => c.value),
        [false, true, true, false]);
  });

  final popupModes = <String, PopupProps<int>>{
    'menu': PopupProps.menu(pinnedItemsProps: _pinProps()),
    'dialog': PopupProps.dialog(pinnedItemsProps: _pinProps()),
    'bottomSheet': PopupProps.bottomSheet(pinnedItemsProps: _pinProps()),
    'modalBottomSheet':
        PopupProps.modalBottomSheet(pinnedItemsProps: _pinProps()),
  };
  for (final entry in popupModes.entries) {
    testWidgets('${entry.key} selects a pinned row through the main list',
        (tester) async {
      await _database.save(tag: _tag, items: ['3']);
      int? selected;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DropdownSearch<int>(
            items: (filter, loadProps) => [1, 2, 3],
            popupProps: entry.value,
            onChanged: (item) => selected = item,
          ),
        ),
      ));
      await tester.tap(find.byType(DropdownSearch<int>));
      await tester.pumpAndSettle();
      expect(_rowOrder(tester), ['3', '1', '2']);
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      expect(selected, 3);
      expect(find.byType(ListView), findsNothing);
    });
  }

  testWidgets('example popup shows saved pins only in its main list',
      (tester) async {
    await _database.save(tag: 'example_pinned_items', items: ['5', '2']);
    await tester.pumpWidget(const MaterialApp(home: SuggestedExample()));
    await tester.tap(find.byType(DropdownSearch<int>));
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['5', '2', '1', '3', '4', '6', '7']);
    expect(find.text('5'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(DropdownSearchPopup<int>),
            matching: find.byType(SingleChildScrollView)),
        findsNothing);
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
  });

  testWidgets('closing a popup before scheduled initialization is safe',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DropdownSearchPopup<int>(
        items: (filter, loadProps) => [1, 2],
        popupProps:
            PopupPropsMultiSelection.dialog(pinnedItemsProps: _pinProps()),
      ),
    ));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('async item results still use saved pin order', (tester) async {
    await _database.save(tag: _tag, items: ['3']);
    final result = Completer<List<int>>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DropdownSearchPopup<int>(
          items: (filter, loadProps) => result.future,
          popupProps:
              PopupPropsMultiSelection.dialog(pinnedItemsProps: _pinProps()),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    result.complete([1, 2, 3]);
    await tester.pumpAndSettle();
    expect(_rowOrder(tester), ['3', '1', '2']);
  });
}

class _Item {
  final int id;
  final String label;

  const _Item(this.id, this.label);
}
