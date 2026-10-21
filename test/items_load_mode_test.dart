import 'dart:async';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PopupProps<String> _props(PopupMode mode) {
  switch (mode) {
    case PopupMode.menu:
      return const PopupProps.menu(
        showSearchBox: true,
        searchDelay: Duration.zero,
      );
    case PopupMode.dialog:
      return const PopupProps.dialog(
        showSearchBox: true,
        searchDelay: Duration.zero,
      );
    case PopupMode.bottomSheet:
      return const PopupProps.bottomSheet(
        showSearchBox: true,
        searchDelay: Duration.zero,
      );
    case PopupMode.modalBottomSheet:
      return const PopupProps.modalBottomSheet(
        showSearchBox: true,
        searchDelay: Duration.zero,
      );
  }
}

Future<void> _mount(
  WidgetTester tester,
  GlobalKey<DropdownSearchState<String>> key, {
  required DropdownSearchOnFind<String> items,
  ItemsLoadMode mode = ItemsLoadMode.onOpen,
  PopupMode popupMode = PopupMode.dialog,
  PopupProps<String>? props,
  bool multi = false,
  DropdownSearchFilterFn<String>? filterFn,
}) async {
  final popupProps = props ?? _props(popupMode);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: multi
              ? DropdownSearch<String>.multiSelection(
                  key: key,
                  items: items,
                  itemsLoadMode: mode,
                  filterFn: filterFn,
                  popupProps: PopupPropsMultiSelection.from(popupProps),
                )
              : DropdownSearch<String>(
                  key: key,
                  items: items,
                  itemsLoadMode: mode,
                  filterFn: filterFn,
                  popupProps: popupProps,
                ),
        ),
      ),
    ),
  ));
}

Future<void> _open(
  WidgetTester tester,
  GlobalKey<DropdownSearchState<String>> key,
) async {
  key.currentState!.openDropDownSearch();
  await tester.pumpAndSettle();
}

Future<void> _close(
  WidgetTester tester,
  GlobalKey<DropdownSearchState<String>> key,
) async {
  key.currentState!.closeDropDownSearch();
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

void main() {
  for (final popupMode in PopupMode.values) {
    for (final multi in [false, true]) {
      final description = '$popupMode, multi=$multi';

      testWidgets('default reloads on every opening ($description)',
          (tester) async {
        final key = GlobalKey<DropdownSearchState<String>>();
        var calls = 0;
        await _mount(tester, key,
            popupMode: popupMode,
            multi: multi,
            items: (filter, props) => ['item-${++calls}']);
        expect(calls, 0);
        await _open(tester, key);
        expect(key.currentState!.popupGetItems, ['item-1']);
        await _close(tester, key);
        await _open(tester, key);
        expect(calls, 2);
        expect(key.currentState!.popupGetItems, ['item-2']);
      });

      testWidgets('manual never loads automatically ($description)',
          (tester) async {
        final key = GlobalKey<DropdownSearchState<String>>();
        var calls = 0;
        await _mount(tester, key,
            mode: ItemsLoadMode.manual,
            popupMode: popupMode,
            multi: multi, items: (filter, props) {
          expect(filter, '');
          expect(props, isNull);
          calls++;
          return ['apple', 'banana'];
        });
        await _open(tester, key);
        expect(calls, 0);
        expect(key.currentState!.popupGetItems, isEmpty);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await _search(tester, 'apple');
        expect(calls, 0);
        await key.currentState!.loadItems();
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(key.currentState!.popupGetItems, ['apple']);
        await _close(tester, key);
        await _open(tester, key);
        expect(calls, 1);
        expect(key.currentState!.popupGetItems, ['apple', 'banana']);
      });

      testWidgets('first opening loads once ($description)', (tester) async {
        final key = GlobalKey<DropdownSearchState<String>>();
        var calls = 0;
        await _mount(tester, key,
            mode: ItemsLoadMode.onFirstOpen,
            popupMode: popupMode,
            multi: multi, items: (filter, props) {
          expect(filter, '');
          expect(props, isNull);
          calls++;
          return ['apple', 'banana'];
        });
        expect(calls, 0);
        await _open(tester, key);
        await _search(tester, 'banana');
        expect(calls, 1);
        expect(key.currentState!.popupGetItems, ['banana']);
        await _close(tester, key);
        await _open(tester, key);
        expect(calls, 1);
        expect(key.currentState!.popupGetItems, ['apple', 'banana']);
      });
    }
  }

  for (final mode in [ItemsLoadMode.manual, ItemsLoadMode.onFirstOpen]) {
    testWidgets('preload and closed refresh work in $mode', (tester) async {
      final key = GlobalKey<DropdownSearchState<String>>();
      var calls = 0;
      await _mount(tester, key,
          mode: mode, items: (_, __) => ['item-${++calls}']);
      final result = await key.currentState!.loadItems();
      result.clear();
      await _open(tester, key);
      expect(calls, 1);
      expect(key.currentState!.popupGetItems, ['item-1']);
      await _close(tester, key);
      await key.currentState!.loadItems();
      await _open(tester, key);
      expect(calls, 2);
      expect(key.currentState!.popupGetItems, ['item-2']);
    });

    testWidgets('refresh replaces rather than appends in $mode',
        (tester) async {
      final key = GlobalKey<DropdownSearchState<String>>();
      var calls = 0;
      final shown = <List<String>>[];
      await _mount(tester, key,
          mode: mode,
          props: PopupProps.dialog(
            showSearchBox: true,
            searchDelay: Duration.zero,
            onItemsLoaded: (items) => shown.add(List.of(items)),
          ),
          items: (_, __) =>
              calls++ == 0 ? ['apple', 'banana'] : ['apricot', 'blueberry']);
      await key.currentState!.loadItems();
      await _open(tester, key);
      await _search(tester, 'ap');
      await key.currentState!.loadItems();
      await tester.pumpAndSettle();
      expect(key.currentState!.popupGetItems, ['apricot']);
      expect(shown.last, ['apricot']);
      expect(shown.where((items) => items.contains('apricot')).length, 1);
      await _search(tester, '');
      expect(key.currentState!.popupGetItems, ['apricot', 'blueberry']);
      expect(calls, 2);
    });

    testWidgets('local search overrides popup cache and remote flags in $mode',
        (tester) async {
      final key = GlobalKey<DropdownSearchState<String>>();
      var calls = 0;
      await _mount(tester, key,
          mode: mode,
          props: const PopupProps.dialog(
            showSearchBox: true,
            searchDelay: Duration.zero,
            cacheItems: false,
            disableFilter: true,
          ),
          filterFn: (item, filter) => filter.isEmpty || item == filter,
          items: (_, __) {
            calls++;
            return ['apple', 'pineapple'];
          });
      await key.currentState!.loadItems();
      await _open(tester, key);
      await _search(tester, 'apple');
      expect(key.currentState!.popupGetItems, ['apple']);
      expect(calls, 1);
    });

    testWidgets('ordinary rebuilds and callback replacement preserve $mode',
        (tester) async {
      final key = GlobalKey<DropdownSearchState<String>>();
      var calls = 0;
      await _mount(tester, key, mode: mode, items: (_, __) {
        calls++;
        return ['original'];
      });
      await key.currentState!.loadItems();
      await _mount(tester, key, mode: mode, items: (_, __) {
        calls++;
        return ['replacement'];
      });
      await _open(tester, key);
      expect(calls, 1);
      expect(key.currentState!.popupGetItems, ['original']);
      await key.currentState!.loadItems();
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(key.currentState!.popupGetItems, ['replacement']);
    });
  }

  testWidgets('successful empty first load is cached', (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    var calls = 0;
    await _mount(tester, key, mode: ItemsLoadMode.onFirstOpen, items: (_, __) {
      calls++;
      return [];
    });
    await _open(tester, key);
    await _close(tester, key);
    await _open(tester, key);
    expect(calls, 1);
    expect(key.currentState!.popupGetItems, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('failed initial load retries on the next opening',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    var calls = 0;
    await _mount(tester, key,
        mode: ItemsLoadMode.onFirstOpen,
        props: PopupProps.dialog(
          errorBuilder: (_, __, error) => Text('failed: $error'),
        ), items: (_, __) {
      if (calls++ == 0) throw StateError('offline');
      return ['recovered'];
    });
    await _open(tester, key);
    expect(find.textContaining('offline'), findsOneWidget);
    await _close(tester, key);
    await _open(tester, key);
    expect(calls, 2);
    expect(key.currentState!.popupGetItems, ['recovered']);
  });

  testWidgets('failed refresh propagates and retains the last successful list',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    var calls = 0;
    await _mount(tester, key,
        mode: ItemsLoadMode.manual,
        props: PopupProps.dialog(
          errorBuilder: (_, __, error) => Text('failed: $error'),
        ), items: (_, __) {
      if (calls++ == 1) return Future.error(StateError('offline'));
      return ['saved'];
    });
    await key.currentState!.loadItems();
    await _open(tester, key);
    await expectLater(key.currentState!.loadItems(), throwsStateError);
    await tester.pumpAndSettle();
    expect(find.textContaining('offline'), findsOneWidget);
    expect(key.currentState!.popupGetItems, ['saved']);
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    expect(find.textContaining('offline'), findsNothing);
    expect(key.currentState!.popupGetItems, ['saved']);
  });

  testWidgets('concurrent requests share a load and return separate lists',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    final pending = Completer<List<String>>();
    var calls = 0;
    await _mount(tester, key, mode: ItemsLoadMode.onFirstOpen, items: (_, __) {
      calls++;
      return pending.future;
    });
    final first = key.currentState!.loadItems();
    final second = key.currentState!.loadItems();
    key.currentState!.openDropDownSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    pending.complete(['loaded']);
    final results = await Future.wait([first, second]);
    results.first.clear();
    expect(results.last, ['loaded']);
    await tester.pumpAndSettle();
    expect(key.currentState!.popupGetItems, ['loaded']);
    expect(calls, 1);
  });

  testWidgets('closing during a load retains its result for reopening',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    final pending = Completer<List<String>>();
    var calls = 0;
    await _mount(tester, key, mode: ItemsLoadMode.onFirstOpen, items: (_, __) {
      calls++;
      return pending.future;
    });
    key.currentState!.openDropDownSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _close(tester, key);
    pending.complete(['loaded while closed']);
    await tester.pump();
    await _open(tester, key);
    expect(calls, 1);
    expect(key.currentState!.popupGetItems, ['loaded while closed']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposal ignores late loading results', (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    final pending = Completer<List<String>>();
    await _mount(tester, key,
        mode: ItemsLoadMode.manual, items: (_, __) => pending.future);
    final state = key.currentState!;
    final load = state.loadItems();
    state.openDropDownSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox());
    pending.complete(['late']);
    expect(await load, ['late']);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(state.loadItems(), throwsStateError);
  });

  testWidgets('mode changes reset the cache and discard old pending results',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    final pending = Completer<List<String>>();
    await _mount(tester, key,
        mode: ItemsLoadMode.manual, items: (_, __) => pending.future);
    final oldLoad = key.currentState!.loadItems();
    await _mount(tester, key,
        mode: ItemsLoadMode.onFirstOpen, items: (_, __) => ['new mode']);
    await _open(tester, key);
    pending.complete(['old mode']);
    await oldLoad;
    await tester.pumpAndSettle();
    expect(key.currentState!.popupGetItems, ['new mode']);
    await _close(tester, key);
    await _open(tester, key);
    expect(key.currentState!.popupGetItems, ['new mode']);
  });

  testWidgets('changing modes while open updates the active popup',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    var calls = 0;
    List<String> items(String filter, LoadProps? props) => ['item-${++calls}'];
    await _mount(tester, key, mode: ItemsLoadMode.onFirstOpen, items: items);
    await _open(tester, key);
    expect(key.currentState!.popupGetItems, ['item-1']);
    await _mount(tester, key, mode: ItemsLoadMode.manual, items: items);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(key.currentState!.popupGetItems, isEmpty);
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    expect(key.currentState!.popupGetItems, ['item-2']);
    await _mount(tester, key, mode: ItemsLoadMode.onOpen, items: items);
    await tester.pumpAndSettle();
    expect(key.currentState!.popupGetItems, ['item-3']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'explicit onOpen loading refreshes without changing reopen policy',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    var calls = 0;
    await _mount(tester, key, items: (_, __) => ['item-${++calls}']);
    await key.currentState!.loadItems();
    await _open(tester, key);
    expect(key.currentState!.popupGetItems, ['item-2']);
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    expect(key.currentState!.popupGetItems, ['item-3']);
    await _close(tester, key);
    await _open(tester, key);
    expect(key.currentState!.popupGetItems, ['item-4']);
  });

  testWidgets('retrieveItems does not populate the manual cache',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    await _mount(tester, key,
        mode: ItemsLoadMode.manual, items: (_, __) => ['retrieved']);
    expect(await key.currentState!.retrieveItems(), ['retrieved']);
    await _open(tester, key);
    expect(key.currentState!.popupGetItems, isEmpty);
  });

  testWidgets('onOpen keeps remote search and pagination props',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    final filters = <String>[];
    final pages = <LoadProps?>[];
    await _mount(tester, key,
        props: const PopupProps.dialog(
          showSearchBox: true,
          searchDelay: Duration.zero,
          disableFilter: true,
          infiniteScrollProps: InfiniteScrollProps(
            loadProps: LoadProps(skip: 10, take: 5),
          ),
        ), items: (filter, props) {
      filters.add(filter);
      pages.add(props);
      return ['remote-$filter'];
    });
    await key.currentState!.loadItems();
    await _open(tester, key);
    await _search(tester, 'query');
    expect(filters, ['', '', 'query']);
    expect(pages.map((page) => page!.skip), [10, 10, 10]);
    expect(pages.map((page) => page!.take), [5, 5, 5]);
    expect(key.currentState!.popupGetItems, ['remote-query']);
  });

  testWidgets('explicit refresh supersedes a pending onOpen result',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    final pending = Completer<List<String>>();
    var calls = 0;
    await _mount(tester, key, items: (_, __) {
      if (calls++ == 0) return pending.future;
      return ['refreshed'];
    });
    key.currentState!.openDropDownSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await key.currentState!.loadItems();
    await tester.pumpAndSettle();
    expect(key.currentState!.popupGetItems, ['refreshed']);
    pending.complete(['outdated']);
    await tester.pumpAndSettle();
    expect(key.currentState!.popupGetItems, ['refreshed']);
  });

  testWidgets('changing modes during first-open loading ignores the old result',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    final pending = Completer<List<String>>();
    await _mount(tester, key,
        mode: ItemsLoadMode.onFirstOpen, items: (_, __) => pending.future);
    key.currentState!.openDropDownSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _mount(tester, key,
        mode: ItemsLoadMode.onOpen, items: (_, __) => ['new mode']);
    await tester.pumpAndSettle();
    expect(key.currentState!.popupGetItems, ['new mode']);
    pending.complete(['outdated']);
    await tester.pumpAndSettle();
    expect(key.currentState!.popupGetItems, ['new mode']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mode changes work without rebuilding the popup route',
      (tester) async {
    final key = GlobalKey<DropdownSearchState<String>>();
    final mode = ValueNotifier(ItemsLoadMode.onFirstOpen);
    addTearDown(mode.dispose);
    final pending = Completer<List<String>>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<ItemsLoadMode>(
          valueListenable: mode,
          builder: (_, value, __) => DropdownSearch<String>(
            key: key,
            itemsLoadMode: value,
            items: (_, __) {
              if (value == ItemsLoadMode.onFirstOpen) return pending.future;
              return ['new source'];
            },
            popupProps: const PopupProps.dialog(),
          ),
        ),
      ),
    ));
    key.currentState!.openDropDownSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    mode.value = ItemsLoadMode.onOpen;
    await tester.pumpAndSettle();
    expect(key.currentState!.popupGetItems, ['new source']);
    pending.complete(['old source']);
    await tester.pumpAndSettle();
    expect(key.currentState!.popupGetItems, ['new source']);
  });

  for (final mode in [ItemsLoadMode.manual, ItemsLoadMode.onFirstOpen]) {
    test('infinite scroll is rejected by the single constructor for $mode', () {
      const props = PopupProps<String>.dialog(
        disableFilter: true,
        infiniteScrollProps: InfiniteScrollProps(),
      );
      expect(
        () => DropdownSearch<String>(itemsLoadMode: mode, popupProps: props),
        throwsAssertionError,
      );
    });
    testWidgets('infinite scroll is rejected at runtime for multi $mode',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: DropdownSearch<String>.multiSelection(
          itemsLoadMode: mode,
          popupProps: const PopupPropsMultiSelection.dialog(
            disableFilter: true,
            infiniteScrollProps: InfiniteScrollProps(),
          ),
        ),
      ));
      expect(tester.takeException(), isArgumentError);
    });
  }
}
