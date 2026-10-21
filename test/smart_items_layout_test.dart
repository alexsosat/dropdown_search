import 'dart:async';
import 'dart:convert';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:dropdown_search/src/data/data_sources/pinned_items_database.dart';
import 'package:dropdown_search/src/data/data_sources/smart_selection_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/history_preferences.dart';

const _tag = 'smart-layout';
final _history = SmartSelectionDatabase();

Future<void> _click(int item, {int count = 1, DateTime? at}) async {
  for (var i = 0; i < count; i++) {
    await _history.recordClick(
        tag: _tag,
        item: '$item',
        at: at ?? DateTime.now().subtract(const Duration(minutes: 1)));
  }
}

SmartSelectionProps<int> _props(
        {bool autoSelect = false,
        String prefix = 'smart',
        ValueChanged<List<int>>? capture}) =>
    SmartSelectionProps(
      tag: _tag,
      usageRange: const Duration(days: 7),
      autoSelect: autoSelect,
      itemToString: (item) => '$item',
      itemFromString: int.parse,
      listBuilder: (context, items, selectItem) {
        capture?.call(items);
        return Wrap(key: ValueKey('$prefix-list'), children: [
          for (final item in items)
            ActionChip(
                key: ValueKey('$prefix-$item'),
                label: Text('Top $item'),
                onPressed: () => selectItem(item)),
        ]);
      },
    );

Future<void> _mount(
    WidgetTester tester, GlobalKey<DropdownSearchState<int>> key,
    {SmartSelectionProps<int>? props,
    DropdownSearchOnFind<int>? items,
    PopupProps<int>? popupProps,
    ItemsLoadMode mode = ItemsLoadMode.manual,
    BeforeChange<int>? veto,
    int? selected}) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: DropdownSearch<int>(
    key: key,
    items: items ?? (_, __) => [1, 2, 3, 4, 5, 6],
    itemsLoadMode: mode,
    smartSelectionProps: props ?? _props(),
    popupProps: popupProps ??
        const PopupProps.dialog(
            showSearchBox: true, searchDelay: Duration.zero),
    onBeforeChange: veto,
    selectedItem: selected,
  ))));
  await tester.pumpAndSettle();
}

Future<void> _open(
    WidgetTester tester, GlobalKey<DropdownSearchState<int>> key) async {
  key.currentState!.openDropDownSearch();
  await tester.pumpAndSettle();
}

Future<Map<String, dynamic>> _stored() async {
  await _history.mostUsed(tag: _tag, usageRange: const Duration(days: 7));
  final data = await SharedPreferencesAsync()
      .getString('dropdown_search:smart_selection:$_tag');
  return data == null ? {} : jsonDecode(data) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = HistoryPreferences();
  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance = backend;
    await PinnedItemsDatabase.init();
  });
  setUp(() async {
    backend.failReads = false;
    backend.failWrites = false;
    await DropdownSearchCache.clearAll();
  });

  testWidgets('default-off tracking builds three ranked, immutable popup items',
      (tester) async {
    await _click(1, count: 4);
    await _click(2, count: 3);
    await _click(3, count: 2);
    await _click(4);
    final key = GlobalKey<DropdownSearchState<int>>();
    List<int> latest = [];
    await _mount(tester, key,
        props: _props(capture: (items) => latest = items));
    expect(key.currentState!.widget.smartSelectionProps!.autoSelect, isFalse);
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem, isNull);
    expect(find.byKey(const ValueKey('smart-list')), findsNothing);
    await _open(tester, key);
    expect(latest, [1, 2, 3]);
    expect(() => latest.add(9), throwsUnsupportedError);
    expect(tester.getTopLeft(find.byKey(const ValueKey('smart-list'))).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(TextField)).dy));
    await tester.enterText(find.byType(TextField), '6');
    await tester.pumpAndSettle();
    expect(latest, [1, 2, 3]);
    expect(find.widgetWithText(ListTile, '1'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('smart-2')));
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem, 2);
    expect(find.byType(DropdownSearchPopup<int>), findsNothing);
    final records = (await _stored())['2'] as List;
    expect(records.fold<int>(0, (n, row) => n + row['count'] as int), 4);
  });

  testWidgets('ties sort by latest usage and identifier without auto-selecting',
      (tester) async {
    final date = DateTime.now().subtract(const Duration(minutes: 1));
    await _click(1, at: date.subtract(const Duration(seconds: 1)));
    await _click(3, at: date);
    await _click(2, at: date);
    List<int> latest = [];
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key,
        props: _props(autoSelect: true, capture: (v) => latest = v));
    await key.currentState!.loadItems();
    await _open(tester, key);
    expect(latest, [2, 3, 1]);
    expect(key.currentState!.getSelectedItem, isNull);
  });

  testWidgets('complete lists prune all missing IDs and keep disabled history',
      (tester) async {
    await _click(99, count: 10);
    await _click(1, count: 5);
    await _click(2, count: 4);
    await _click(3, count: 3);
    await _click(4, count: 2);
    await _click(5);
    List<int> latest = [];
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key,
        selected: 3,
        props: _props(capture: (v) => latest = v),
        popupProps: PopupProps.dialog(disabledItemFn: (item) => item == 1));
    await key.currentState!.loadItems();
    await _open(tester, key);
    expect(latest, [2, 3, 4]);
    expect((await _stored()).keys, contains('1'));
    expect((await _stored()).keys, isNot(contains('99')));
    expect(key.currentState!.getSelectedItem, 3);
    expect(find.byKey(const ValueKey('smart-list')), findsOneWidget);
  });

  testWidgets(
      'filtered-only results do not validate or prune original membership',
      (tester) async {
    await _click(2);
    await _click(99);
    final search = TextEditingController(text: '1');
    addTearDown(search.dispose);
    final key = GlobalKey<DropdownSearchState<int>>();
    List<int> latest = [];
    await _mount(tester, key,
        mode: ItemsLoadMode.onOpen,
        items: (filter, _) => filter.isEmpty ? [1, 2] : [1],
        props: _props(capture: (v) => latest = v),
        popupProps: PopupProps.dialog(
            showSearchBox: true,
            searchDelay: Duration.zero,
            searchFieldProps: TextFieldProps(controller: search)));
    await _open(tester, key);
    expect(latest, isEmpty);
    expect((await _stored()).keys, containsAll(['2', '99']));
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(latest, [2]);
    expect((await _stored()).keys, ['2']);
  });

  testWidgets(
      'partial pagination preserves unseen history and defers its leader',
      (tester) async {
    await _click(4, count: 2);
    await _click(1);
    await _click(99);
    final secondPage = Completer<List<int>>();
    final key = GlobalKey<DropdownSearchState<int>>();
    List<int> latest = [];
    await _mount(tester, key,
        mode: ItemsLoadMode.onOpen,
        props: _props(autoSelect: true, capture: (v) => latest = v),
        popupProps: const PopupProps.dialog(
            disableFilter: true,
            infiniteScrollProps:
                InfiniteScrollProps(loadProps: LoadProps(take: 2))),
        items: (_, load) {
      if (load!.skip == 0) return [1, 2];
      if (load.skip == 2) return secondPage.future;
      return <int>[];
    });
    key.currentState!.openDropDownSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(latest, [1]);
    expect(key.currentState!.getSelectedItem, isNull);
    expect((await _stored()).keys, containsAll(['4', '99']));
    secondPage.complete([3, 4]);
    await tester.pumpAndSettle();
    expect(latest, [4, 1]);
    expect(key.currentState!.getSelectedItem, 4);
    expect((await _stored()).keys, isNot(contains('99')));
    expect(tester.widget<ListTile>(find.widgetWithText(ListTile, '4')).trailing,
        isNull);
    key.currentState!.closeDropDownSearch();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'failed loads preserve history and a complete empty list removes it',
      (tester) async {
    await _click(2);
    final key = GlobalKey<DropdownSearchState<int>>();
    var fail = true;
    await _mount(tester, key, items: (_, __) {
      if (fail) throw StateError('Unavailable');
      return [];
    });
    await expectLater(key.currentState!.loadItems(), throwsStateError);
    expect((await _stored()).keys, ['2']);
    fail = false;
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    expect(await _stored(), isEmpty);
  });

  for (final mode in [ItemsLoadMode.onOpen, ItemsLoadMode.onFirstOpen]) {
    testWidgets(
        '$mode defers auto-select until opening and synchronizes the popup',
        (tester) async {
      await _click(2);
      var requests = 0;
      final key = GlobalKey<DropdownSearchState<int>>();
      await _mount(tester, key,
          mode: mode,
          props: _props(autoSelect: true),
          popupProps: const PopupProps.dialog(showSelectedItems: true),
          items: (_, __) {
        requests++;
        return [1, 2];
      });
      expect(requests, 0);
      expect(key.currentState!.getSelectedItem, isNull);
      await _open(tester, key);
      expect(requests, 1);
      expect(key.currentState!.getSelectedItem, 2);
      expect(
          tester.widget<ListTile>(find.widgetWithText(ListTile, '2')).selected,
          isTrue);
      expect(find.byType(DropdownSearchPopup<int>), findsOneWidget);
      final records = (await _stored())['2'] as List;
      expect(records.fold<int>(0, (n, row) => n + row['count'] as int), 1);
      key.currentState!.closeDropDownSearch();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('smart shortcuts honor vetoes and still record the user tap',
      (tester) async {
    await _click(2);
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key, veto: (_, __) async => false);
    await key.currentState!.loadItems();
    await _open(tester, key);
    await tester.tap(find.byKey(const ValueKey('smart-2')));
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem, isNull);
    final records = (await _stored())['2'] as List;
    expect(records.fold<int>(0, (n, row) => n + row['count'] as int), 2);
  });

  testWidgets('shared-tag builders refresh after external writes and clearing',
      (tester) async {
    await _click(1);
    final a = GlobalKey<DropdownSearchState<int>>();
    final b = GlobalKey<DropdownSearchState<int>>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      for (final key in [a, b])
        DropdownSearch<int>(
            key: key,
            items: (_, __) => [1, 2],
            itemsLoadMode: ItemsLoadMode.manual,
            smartSelectionProps: _props(prefix: key == a ? 'a' : 'b'),
            popupProps: const PopupProps.dialog()),
    ]))));
    await a.currentState!.loadItems();
    await b.currentState!.loadItems();
    await _open(tester, a);
    expect(find.byKey(const ValueKey('a-1')), findsOneWidget);
    a.currentState!.closeDropDownSearch();
    await tester.pumpAndSettle();
    await _click(2, count: 3);
    await _open(tester, b);
    final chips =
        tester.widget<Wrap>(find.byKey(const ValueKey('b-list'))).children;
    expect(chips.first.key, const ValueKey('b-2'));
    await DropdownSearchCache.clearSmartSelection(tag: _tag);
    await tester.pumpAndSettle();
    expect(tester.widget<Wrap>(find.byKey(const ValueKey('b-list'))).children,
        isEmpty);
    b.currentState!.closeDropDownSearch();
    await tester.pumpAndSettle();
    await _open(tester, a);
    expect(tester.widget<Wrap>(find.byKey(const ValueKey('a-list'))).children,
        isEmpty);
    a.currentState!.closeDropDownSearch();
    await tester.pumpAndSettle();
  });

  testWidgets('a superseded source snapshot cannot prune newer source history',
      (tester) async {
    await _click(1);
    await _click(2, count: 2);
    var data = [1];
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key, items: (_, __) => List.of(data));
    final gate = Completer<void>();
    backend.readGate = gate;
    await key.currentState!.loadItems();
    await tester.pump();
    data = [1, 2];
    await key.currentState!.loadItems();
    backend.readGate = null;
    gate.complete();
    await tester.pumpAndSettle();
    expect((await _stored()).keys, containsAll(['1', '2']));
    await _open(tester, key);
    expect(
        tester
            .widget<Wrap>(find.byKey(const ValueKey('smart-list')))
            .children
            .first
            .key,
        const ValueKey('smart-2'));
    final previousCallback = tester
        .widget<ActionChip>(find.byKey(const ValueKey('smart-2')))
        .onPressed!;
    data = [1];
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    previousCallback();
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem, isNull);
    expect((await _stored()).keys, isNot(contains('2')));
    key.currentState!.closeDropDownSearch();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'newly enabled shortcuts use current eligibility in an open popup',
      (tester) async {
    await _click(2);
    final key = GlobalKey<DropdownSearchState<int>>();
    final props = _props();
    Widget view(bool disabled) => MaterialApp(
        home: Scaffold(
            body: DropdownSearch<int>(
                key: key,
                items: (_, __) => [1, 2],
                itemsLoadMode: ItemsLoadMode.manual,
                smartSelectionProps: props,
                popupProps: PopupProps.dialog(
                    disabledItemFn: (item) => disabled && item == 2))));
    await tester.pumpWidget(view(true));
    await key.currentState!.loadItems();
    await _open(tester, key);
    expect(find.byKey(const ValueKey('smart-2')), findsNothing);
    await tester.pumpWidget(view(false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('smart-2')));
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem, 2);
  });

  testWidgets('a nonzero initial page offset cannot prove full membership',
      (tester) async {
    await _click(1);
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key,
        mode: ItemsLoadMode.onOpen,
        popupProps: const PopupProps.dialog(
            disableFilter: true,
            infiniteScrollProps:
                InfiniteScrollProps(loadProps: LoadProps(skip: 2, take: 2))),
        items: (_, __) => [3]);
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    expect((await _stored()).keys, ['1']);
  });

  testWidgets(
      'disabling auto-select cancels pending approval but retains shortcuts',
      (tester) async {
    await _click(2);
    final key = GlobalKey<DropdownSearchState<int>>();
    final decision = Completer<bool?>();
    var asked = false;
    await _mount(tester, key, props: _props(autoSelect: true), veto: (_, __) {
      asked = true;
      return decision.future;
    });
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    expect(asked, isTrue);
    await _mount(tester, key, props: _props());
    decision.complete(true);
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem, isNull);
    await _open(tester, key);
    expect(find.byKey(const ValueKey('smart-2')), findsOneWidget);
    key.currentState!.closeDropDownSearch();
    await tester.pumpAndSettle();
  });

  testWidgets('range and tag changes refresh an already-open popup builder',
      (tester) async {
    await _click(1);
    await _click(2,
        count: 2, at: DateTime.now().subtract(const Duration(days: 8)));
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key);
    await key.currentState!.loadItems();
    await _open(tester, key);
    expect(find.byKey(const ValueKey('smart-2')), findsNothing);
    SmartSelectionProps<int> changed(String tag, Duration range) =>
        SmartSelectionProps(
            tag: tag,
            usageRange: range,
            itemToString: (item) => '$item',
            itemFromString: int.parse,
            listBuilder: _props().listBuilder);
    await _mount(tester, key, props: changed(_tag, const Duration(days: 30)));
    expect(
        tester
            .widget<Wrap>(find.byKey(const ValueKey('smart-list')))
            .children
            .first
            .key,
        const ValueKey('smart-2'));
    await _history.recordClick(tag: 'another-tag', item: '3');
    await _mount(tester, key,
        props: changed('another-tag', const Duration(days: 7)));
    expect(find.byKey(const ValueKey('smart-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('smart-1')), findsNothing);
    key.currentState!.closeDropDownSearch();
    await tester.pumpAndSettle();
  });

  testWidgets('disabled dropdowns cannot select through a smart callback',
      (tester) async {
    await _click(2);
    final key = GlobalKey<DropdownSearchState<int>>();
    final props = _props();
    Widget view(bool enabled) => MaterialApp(
        home: Scaffold(
            body: DropdownSearch<int>(
                key: key,
                items: (_, __) => [1, 2],
                itemsLoadMode: ItemsLoadMode.manual,
                enabled: enabled,
                smartSelectionProps: props,
                popupProps: const PopupProps.dialog())));
    await tester.pumpWidget(view(true));
    await key.currentState!.loadItems();
    await _open(tester, key);
    final callback = tester
        .widget<ActionChip>(find.byKey(const ValueKey('smart-2')))
        .onPressed!;
    await tester.pumpWidget(view(false));
    await tester.pumpAndSettle();
    callback();
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem, isNull);
    final records = (await _stored())['2'] as List;
    expect(records.fold<int>(0, (n, row) => n + row['count'] as int), 1);
    key.currentState!.closeDropDownSearch();
    await tester.pumpAndSettle();
  });

  testWidgets('suggestions render below validation errors and custom fields',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<int>>();
    final popup = PopupProps<int>.dialog(
        suggestedItemProps: SuggestedItemProps(
            showSuggestedItems: true,
            suggestedItems: [1],
            suggestedItemBuilder: (_, item, selected) =>
                Text('suggestion:$item')));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DropdownSearch<int>(
                key: key,
                items: (_, __) => [1],
                itemsLoadMode: ItemsLoadMode.manual,
                popupProps: popup,
                validator: (_) => 'Choose a value',
                autoValidateMode: AutovalidateMode.always))));
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(find.text('suggestion:1')).dy,
        greaterThanOrEqualTo(
            tester.getBottomLeft(find.text('Choose a value')).dy));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DropdownSearch<int>(
                key: key,
                items: (_, __) => [1],
                itemsLoadMode: ItemsLoadMode.manual,
                mode: Mode.custom,
                dropdownBuilder: (_, value) => const Text('Custom field'),
                popupProps: popup))));
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    expect(
        tester.getTopLeft(find.text('suggestion:1')).dy,
        greaterThanOrEqualTo(
            tester.getBottomLeft(find.text('Custom field')).dy));
    await tester.tap(find.text('suggestion:1'));
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem, 1);
    expect(find.byType(DropdownSearchPopup<int>), findsNothing);
  });

  testWidgets('empty and failed loads preserve independent suggestions',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<int>>();
    var fail = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: DropdownSearch<int>(
      key: key,
      itemsLoadMode: ItemsLoadMode.manual,
      items: (_, __) {
        if (fail) throw StateError('Unavailable');
        return [];
      },
      popupProps: PopupProps.dialog(
          suggestedItemProps: SuggestedItemProps(
        showSuggestedItems: true,
        suggestedItems: [9],
        suggestedItemBuilder: (_, item, selected) => Text('shortcut:$item'),
      )),
    ))));
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    expect(find.text('shortcut:9'), findsOneWidget);
    fail = true;
    await expectLater(key.currentState!.loadItems(), throwsStateError);
    await tester.pumpAndSettle();
    expect(find.text('shortcut:9'), findsOneWidget);
    expect(key.currentState!.popupGetSuggestedItems, [9]);
  });

  for (final mode in ItemsLoadMode.values) {
    testWidgets('independent suggestions render immediately with $mode',
        (tester) async {
      var requests = 0;
      final key = GlobalKey<DropdownSearchState<int>>();
      var suggestions = <int>[9, 10];
      Widget view({bool show = true, bool enabled = true}) => MaterialApp(
            home: Scaffold(
                body: DropdownSearch<int>(
              key: key,
              enabled: enabled,
              itemsLoadMode: mode,
              items: (_, __) {
                requests++;
                return [1, 2];
              },
              popupProps: PopupProps.dialog(
                disabledItemFn: (item) => item == 10,
                suggestedItemProps: SuggestedItemProps(
                  showSuggestedItems: show,
                  suggestedItems: suggestions,
                  suggestedItemBuilder: (_, item, selected) =>
                      Text('shortcut:$item:$selected'),
                ),
              ),
            )),
          );
      await tester.pumpWidget(view());
      expect(find.text('shortcut:9:false'), findsOneWidget);
      expect(requests, 0);
      await tester.tap(find.text('shortcut:10:false'));
      await tester.pumpAndSettle();
      expect(key.currentState!.getSelectedItem, isNull);
      await tester.pumpWidget(view(enabled: false));
      await tester.tap(find.text('shortcut:9:false'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(key.currentState!.getSelectedItem, isNull);
      await tester.pumpWidget(view());
      await tester.tap(find.text('shortcut:9:false'));
      await tester.pumpAndSettle();
      expect(key.currentState!.getSelectedItem, 9);
      expect(requests, 0);
      await key.currentState!.loadItems();
      await tester.pumpAndSettle();
      expect(key.currentState!.popupGetSuggestedItems, [9, 10]);
      suggestions = [8];
      await tester.pumpWidget(view());
      expect(find.text('shortcut:8:false'), findsOneWidget);
      expect(find.text('shortcut:9:true'), findsNothing);
      await tester.pumpWidget(view(show: false));
      expect(find.text('shortcut:8:false'), findsNothing);
    });
  }

  for (final multi in [false, true]) {
    testWidgets('field suggestions select directly with multi=$multi',
        (tester) async {
      final key = GlobalKey<DropdownSearchState<int>>();
      final popup = PopupPropsMultiSelection<int>.dialog(
          suggestedItemProps: SuggestedItemProps(
              showSuggestedItems: true,
              suggestedItems: [1, 2],
              suggestedItemBuilder: (_, item, selected) =>
                  Text('suggestion:$item:$selected')));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: multi
                  ? DropdownSearch<int>.multiSelection(
                      key: key,
                      items: (_, __) => [1, 2],
                      itemsLoadMode: ItemsLoadMode.manual,
                      popupProps: popup)
                  : DropdownSearch<int>(
                      key: key,
                      items: (_, __) => [1, 2],
                      itemsLoadMode: ItemsLoadMode.manual,
                      popupProps: popup,
                      smartSelectionProps: _props()))));
      await tester.pumpAndSettle();
      expect(find.text('suggestion:1:false'), findsOneWidget);
      expect(
          tester.getTopLeft(find.text('suggestion:1:false')).dy,
          greaterThanOrEqualTo(tester
              .getBottomLeft(
                  find.byType(multi ? FormField<List<int>> : FormField<int>))
              .dy));
      await tester.tap(find.text('suggestion:1:false'));
      await tester.pumpAndSettle();
      expect(key.currentState!.getSelectedItems, [1]);
      expect(find.byType(DropdownSearchPopup<int>), findsNothing);
      expect(key.currentState!.popupGetSuggestedItems, [1, 2]);
      if (multi) {
        await tester.tap(find.text('suggestion:1:true'));
        await tester.pumpAndSettle();
        expect(key.currentState!.getSelectedItems, isEmpty);
      } else {
        expect((await _stored()).keys, ['1']);
      }
    });
  }
}
