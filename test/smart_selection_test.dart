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

const _tag = 'smart-widget';
final _history = SmartSelectionDatabase();

SmartSelectionProps<int> _props({String tag = _tag, Duration? range}) =>
    SmartSelectionProps(
      tag: tag,
      autoSelect: true,
      usageRange: range ?? const Duration(days: 7),
      itemToString: (item) => '$item',
      itemFromString: int.parse,
    );

Future<void> _seed(int item, {String tag = _tag, DateTime? at}) =>
    _history.recordClick(
      tag: tag,
      item: '$item',
      at: at ?? DateTime.now().subtract(const Duration(minutes: 1)),
    );

Future<Map<String, int>> _counts() async {
  // Wait for all preceding background tap writes before inspecting storage.
  await _history.mostUsed(tag: _tag, usageRange: const Duration(days: 7));
  final stored = await SharedPreferencesAsync()
      .getString('dropdown_search:smart_selection:$_tag');
  if (stored == null) return {};
  final data = jsonDecode(stored) as Map<String, dynamic>;
  return data.map((key, records) => MapEntry(key,
      (records as List).fold<int>(0, (sum, row) => sum + row['count'] as int)));
}

Future<void> _mount(
  WidgetTester tester,
  GlobalKey<DropdownSearchState<int>> key, {
  SmartSelectionProps<int>? smartProps,
  int? selected,
  ValueChanged<int?>? onChanged,
  BeforeChange<int>? beforeChange,
  PopupProps<int>? popupProps,
  DropdownSearchOnFind<int>? items,
  ItemsLoadMode loadMode = ItemsLoadMode.onOpen,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: DropdownSearch<int>(
        key: key,
        selectedItem: selected,
        smartSelectionProps: smartProps ?? _props(),
        onChanged: onChanged,
        onBeforeChange: beforeChange,
        popupProps: popupProps ?? const PopupProps.dialog(),
        items: items ?? (_, __) => [1, 2, 3],
        itemsLoadMode: loadMode,
      ),
    ),
  ));
  if (selected == null &&
      key.currentState!.widget.smartSelectionProps?.autoSelect == true) {
    await key.currentState!.loadItems();
  }
  await tester.pumpAndSettle();
}

Future<void> _tapItem(WidgetTester tester,
    GlobalKey<DropdownSearchState<int>> key, int item) async {
  key.currentState!.openDropDownSearch();
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, '$item'));
  await tester.pumpAndSettle();
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
    backend.readGate = null;
    backend.readStarted = null;
    await DropdownSearchCache.clearAll();
  });

  testWidgets('auto-selection waits for explicit original loading',
      (tester) async {
    for (var i = 0; i < 3; i++) {
      await _seed(1, at: DateTime.now().subtract(const Duration(days: 20)));
    }
    await _seed(2);
    final key = GlobalKey<DropdownSearchState<int>>();
    final changed = <int?>[];
    var requests = 0;
    await _mount(tester, key, loadMode: ItemsLoadMode.manual, items: (_, __) {
      requests++;
      return [1, 2, 3];
    }, onChanged: changed.add);
    expect(key.currentState!.getSelectedItem, 2);
    expect(changed, [2]);
    expect(requests, 1);
    expect(await _counts(), {'1': 3, '2': 1});

    await tester.pumpWidget(const SizedBox.shrink());
    await _mount(tester, GlobalKey<DropdownSearchState<int>>(),
        smartProps: _props(range: const Duration(days: 30)));
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('ties and empty windows do not preselect', (tester) async {
    await _seed(1);
    await _seed(2);
    var changes = 0;
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key, onChanged: (_) => changes++);
    expect(key.currentState!.getSelectedItem, isNull);
    expect(changes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await DropdownSearchCache.clearSmartSelection();
    await _mount(tester, key, onChanged: (_) => changes++);
    expect(key.currentState!.getSelectedItem, isNull);
    expect(changes, 0);
  });

  testWidgets('explicit values win and clearing does not rerun startup',
      (tester) async {
    await _seed(2);
    final key = GlobalKey<DropdownSearchState<int>>();
    final changed = <int?>[];
    await _mount(tester, key, selected: 1, onChanged: changed.add);
    expect(key.currentState!.getSelectedItem, 1);
    expect(changed, isEmpty);
    key.currentState!.clear();
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem, isNull);
    expect(changed, [null]);
    expect(await _counts(), {'2': 1});
  });

  testWidgets('startup respects the normal selection veto', (tester) async {
    await _seed(2);
    var vetoes = 0;
    var changes = 0;
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key,
        beforeChange: (old, next) async {
          expectSync(old, isNull);
          expectSync(next, 2);
          vetoes++;
          return false;
        },
        onChanged: (_) => changes++);
    expect(key.currentState!.getSelectedItem, isNull);
    expect(vetoes, 1);
    expect(changes, 0);
    expect(await _counts(), {'2': 1});
  });

  testWidgets('explicit clearing before startup runs cancels preselection',
      (tester) async {
    await _seed(2);
    final key = GlobalKey<DropdownSearchState<int>>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) {
        // Register before the dropdown's own first-frame startup callback.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          key.currentState!.clear();
        });
        return DropdownSearch<int>(
          key: key,
          smartSelectionProps: _props(),
          items: (_, __) => [1, 2, 3],
        );
      },
    ))));
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem, isNull);
  });

  testWidgets('custom objects restore and share history through stable IDs',
      (tester) async {
    await _seed(2);
    final key = GlobalKey<DropdownSearchState<_Choice>>();
    final changes = <_Choice?>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: DropdownSearch<_Choice>(
        key: key,
        items: (_, __) => [const _Choice(1, 'One'), const _Choice(2, 'Two')],
        compareFn: (a, b) => a.id == b.id,
        itemAsString: (item) => item.label,
        popupProps: const PopupProps.dialog(),
        smartSelectionProps: SmartSelectionProps<_Choice>(
          tag: _tag,
          autoSelect: true,
          usageRange: const Duration(days: 7),
          itemToString: (item) => '${item.id}',
          itemFromString: (value) => _Choice(int.parse(value), 'Restored'),
        ),
        onChanged: changes.add,
      ),
    )));
    await tester.pumpAndSettle();
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem!.id, 2);
    expect(changes.single!.label, 'Two');
    key.currentState!.openDropDownSearch();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Two'));
    await tester.pumpAndSettle();
    expect(changes.last!.label, 'Two');
    expect(await _counts(), {'2': 2});
  });

  for (final action in [
    'programmatic',
    'clear',
    'popup',
    'cache',
    'expired-cache',
    'other-tag',
    'configuration',
    'dispose'
  ]) {
    testWidgets('$action during a startup veto cannot apply stale selection',
        (tester) async {
      await _seed(2);
      final decision = Completer<bool?>();
      final key = GlobalKey<DropdownSearchState<int>>();
      var asked = false;
      await _mount(tester, key, beforeChange: (_, next) {
        if (next != 2) return Future.value(true);
        asked = true;
        return decision.future;
      });
      expect(asked, isTrue);
      switch (action) {
        case 'programmatic':
          key.currentState!.changeSelectedItem(1);
          break;
        case 'clear':
          key.currentState!.clear();
          break;
        case 'popup':
          key.currentState!.openDropDownSearch();
          break;
        case 'cache':
          await DropdownSearchCache.clearSmartSelection(tag: _tag);
          break;
        case 'expired-cache':
          await DropdownSearchCache.clearSmartSelection(
              tag: _tag, olderThan: const Duration(days: 7));
          break;
        case 'other-tag':
          await DropdownSearchCache.clearSmartSelection(tag: 'other');
          break;
        case 'configuration':
          await _mount(tester, key, smartProps: _props(tag: 'new'));
          break;
        case 'dispose':
          await tester.pumpWidget(const SizedBox.shrink());
          break;
      }
      decision.complete(true);
      await tester.pumpAndSettle();
      if (action != 'dispose') {
        expect(
            key.currentState!.getSelectedItem,
            action == 'programmatic'
                ? 1
                : (action == 'other-tag' || action == 'popup')
                    ? 2
                    : isNull);
      }
      if (action == 'popup') {
        key.currentState!.closeDropDownSearch();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cache clearing during a delayed history read cancels startup',
      (tester) async {
    await _seed(2);
    final gate = Completer<void>();
    backend.readGate = gate;
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key);
    final clearing = DropdownSearchCache.clearSmartSelection(tag: _tag);
    gate.complete();
    await tester.pumpAndSettle();
    await clearing;
    expect(key.currentState!.getSelectedItem, isNull);
    expect(await _counts(), isEmpty);
  });

  testWidgets(
      'repeated user selections count even when the value stays the same',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key, selected: 2);
    await _tapItem(tester, key, 2);
    await _tapItem(tester, key, 2);
    expect(await _counts(), {'2': 2});
    await tester.pumpWidget(const SizedBox.shrink());
    await _mount(tester, key);
    expect(key.currentState!.getSelectedItem, 2);
  });

  testWidgets('vetoed item taps still count', (tester) async {
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key,
        selected: 1, beforeChange: (_, __) async => false);
    await _tapItem(tester, key, 2);
    expect(key.currentState!.getSelectedItem, 1);
    expect(await _counts(), {'2': 1});
  });

  testWidgets(
      'programmatic changes and automatic one-item selection do not count',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key,
        items: (_, __) => [2],
        popupProps: const PopupProps.dialog(
            itemClickProps: ClickProps(autoSelectIfOnlyOne: true)));
    key.currentState!.changeSelectedItem(1);
    key.currentState!.clear();
    key.currentState!.openDropDownSearch();
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem, 2);
    expect(await _counts(), isEmpty);
  });

  testWidgets('field suggestions count as user taps', (tester) async {
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key,
        popupProps: PopupProps.dialog(
            suggestedItemProps: SuggestedItemProps(
                showSuggestedItems: true, suggestedItems: [2])));
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(SingleChildScrollView), matching: find.text('2')));
    await tester.pumpAndSettle();
    expect(key.currentState!.getSelectedItem, 2);
    expect(await _counts(), {'2': 1});
  });

  testWidgets('pin controls do not count and clearing keeps displayed pins',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key,
        popupProps: PopupProps.dialog(
            pinnedItemsProps: PinnedItemsProps(
          showPinnedItems: true,
          pinnedItemsTag: _tag,
          pinnedItemsEntityTransformer: int.parse,
          pinnedItemsStringTransformer: (item) => '$item',
        )));
    key.currentState!.openDropDownSearch();
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, '2'),
        matching: find.byType(IconButton)));
    await tester.pumpAndSettle();
    expect(await _counts(), isEmpty);
    expect(key.currentState!.getPopupState!.pinnedItems, [2]);
    await DropdownSearchCache.clearPinnedItems(tag: _tag);
    expect(key.currentState!.getPopupState!.pinnedItems, [2]);
    key.currentState!.closeDropDownSearch();
    await tester.pumpAndSettle();
    key.currentState!.openDropDownSearch();
    await tester.pumpAndSettle();
    expect(key.currentState!.getPopupState!.pinnedItems, isEmpty);
    await tester.tap(find.widgetWithText(ListTile, '2'));
    await tester.pumpAndSettle();
    await DropdownSearchCache.clearAll();
    expect(key.currentState!.getSelectedItem, 2);
    expect(await _counts(), isEmpty);
  });

  testWidgets('disabled and unrestorable leaders are not selected',
      (tester) async {
    await _seed(2);
    final key = GlobalKey<DropdownSearchState<int>>();
    await _mount(tester, key,
        popupProps: PopupProps.dialog(disabledItemFn: (item) => item == 2));
    expect(key.currentState!.getSelectedItem, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _mount(tester, key,
        smartProps: SmartSelectionProps<int>(
          tag: _tag,
          usageRange: const Duration(days: 7),
          itemToString: (item) => '$item',
          itemFromString: (_) => throw const FormatException('Missing item'),
        ));
    expect(key.currentState!.getSelectedItem, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final failure in ['read', 'write']) {
    testWidgets('$failure failure leaves ordinary selection usable',
        (tester) async {
      backend.failReads = failure == 'read';
      backend.failWrites = failure == 'write';
      final key = GlobalKey<DropdownSearchState<int>>();
      await _mount(tester, key);
      await _tapItem(tester, key, 2);
      expect(key.currentState!.getSelectedItem, 2);
      backend.failReads = false;
      backend.failWrites = false;
      expect(await _counts(), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}

class _Choice {
  final int id;
  final String label;

  const _Choice(this.id, this.label);
}
