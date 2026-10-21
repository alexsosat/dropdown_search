import 'package:dropdown_search/dropdown_search.dart';
import 'package:example/loading_methods.dart';
import 'package:example/main.dart';
import 'package:example/pinned_items.dart';
import 'package:example/smart_selection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

const _smartTag = 'example_smart_selection';

Future<void> _showPage(WidgetTester tester, Widget page,
    {bool autoSelect = true}) async {
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
  if (page is SmartSelectionExamplePage && autoSelect) {
    await tester.tap(find.byKey(const ValueKey('smart-auto-select')));
    await tester.pumpAndSettle();
  }
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.2);
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, String label) async {
  final target = find.text(label);
  await _reveal(tester, target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

DropdownSearchState<String> _smartState(WidgetTester tester) => tester
    .state<DropdownSearchState<String>>(find.byType(DropdownSearch<String>));

Future<void> _selectCity(WidgetTester tester, String city) async {
  final dropdown = find.byType(DropdownSearch<String>);
  await _reveal(tester, dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, city));
  await tester.pumpAndSettle();
}

Finder _modeDropdown(ItemsLoadMode mode) => find.descendant(
      of: find.byKey(ValueKey('loading-${mode.name}')),
      matching: find.byType(DropdownSearch<String>),
    );

int _requests(WidgetTester tester, ItemsLoadMode mode) => int.parse(tester
    .widget<Text>(find.byKey(ValueKey('requests-${mode.name}')))
    .data!
    .split(': ')
    .last);

Future<void> _openMode(WidgetTester tester, ItemsLoadMode mode) async {
  final dropdown = _modeDropdown(mode);
  await _reveal(tester, dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
}

Future<void> _closeMode(WidgetTester tester, ItemsLoadMode mode) async {
  tester
      .state<DropdownSearchState<String>>(_modeDropdown(mode))
      .closeDropDownSearch();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final preferences = _ExamplePreferences();
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance = preferences;
  });
  setUp(() async {
    preferences.failClears = false;
    await DropdownSearchCache.clearSmartSelection(tag: _smartTag);
    await DropdownSearchCache.clearPinnedItems(
        tag: 'example_pinned_items_page');
  });

  testWidgets(
      'smart selection learns real taps and restores on restart and revisit',
      (tester) async {
    await _showPage(tester, const SmartSelectionExamplePage());
    expect(find.text('Selected value: None'), findsOneWidget);
    final initialState = _smartState(tester);
    await _selectCity(tester, 'Tokyo');
    await _selectCity(tester, 'Tokyo');
    expect(_smartState(tester), same(initialState));
    await _press(tester, 'Restart dropdown');
    expect(_smartState(tester), isNot(same(initialState)));
    expect(find.text('Selected value: Tokyo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _showPage(tester, const SmartSelectionExamplePage());
    expect(find.text('Selected value: Tokyo'), findsOneWidget);
  });

  testWidgets('a tied usage history leaves the restarted dropdown blank',
      (tester) async {
    await _showPage(tester, const SmartSelectionExamplePage());
    await _selectCity(tester, 'Tokyo');
    await _selectCity(tester, 'Paris');
    await _press(tester, 'Restart dropdown');
    expect(find.text('Selected value: None'), findsOneWidget);
  });

  testWidgets(
      'auto-selection defaults off while verified popup shortcuts remain usable',
      (tester) async {
    await _showPage(tester, const SmartSelectionExamplePage(),
        autoSelect: false);
    expect(_smartState(tester).widget.smartSelectionProps!.autoSelect, isFalse);
    await _selectCity(tester, 'Tokyo');
    await _press(tester, 'Restart dropdown');
    expect(find.text('Selected value: None'), findsOneWidget);
    final dropdown = find.byType(DropdownSearch<String>);
    await _reveal(tester, dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    final shortcut = find.byKey(const ValueKey('smart-choice-Tokyo'));
    expect(shortcut, findsOneWidget);
    expect(tester.getTopLeft(shortcut).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(TextField)).dy));
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    expect(find.text('Selected value: Tokyo'), findsOneWidget);
  });

  testWidgets('changing the usage range restarts without deleting history',
      (tester) async {
    await _showPage(tester, const SmartSelectionExamplePage());
    await _selectCity(tester, 'Tokyo');
    final initialState = _smartState(tester);
    final range = find.byKey(const ValueKey('smart-usage-range'));
    await _reveal(tester, range);
    await tester.tap(range);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last hour').last);
    await tester.pumpAndSettle();
    expect(_smartState(tester), isNot(same(initialState)));
    expect(_smartState(tester).widget.smartSelectionProps!.usageRange,
        const Duration(hours: 1));
    expect(find.text('Selected value: Tokyo'), findsOneWidget);
  });

  testWidgets(
      'old-usage clearing keeps recent choices and full clearing resets',
      (tester) async {
    await _showPage(tester, const SmartSelectionExamplePage());
    await _selectCity(tester, 'Tokyo');
    await _press(tester, 'Clear old usage');
    expect(find.text('Selected value: Tokyo'), findsOneWidget);
    await _press(tester, 'Clear saved history');
    expect(find.text('Selected value: None'), findsOneWidget);
  });

  testWidgets('clear failures show feedback and restore the page controls',
      (tester) async {
    await _showPage(tester, const SmartSelectionExamplePage());
    await _selectCity(tester, 'Tokyo');
    preferences.failClears = true;
    await _press(tester, 'Clear saved history');
    expect(find.text('Could not clear history. Please try again.'),
        findsOneWidget);
    expect(find.text('Selected value: Tokyo'), findsOneWidget);
    final restart = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Restart dropdown'));
    expect(restart.onPressed, isNotNull);
    preferences.failClears = false;
  });

  for (final mode in ItemsLoadMode.values) {
    testWidgets(
        '${mode.name} demonstrates opening, search, caching and refresh',
        (tester) async {
      await _showPage(tester, const LoadingMethodsExamplePage());
      for (final other in ItemsLoadMode.values) {
        expect(_requests(tester, other), 0);
      }
      await _openMode(tester, mode);
      if (mode == ItemsLoadMode.manual) {
        expect(_requests(tester, mode), 0);
        expect(find.text('Use Load / refresh to fetch choices first.'),
            findsOneWidget);
        await _closeMode(tester, mode);
        final refresh = find.byKey(ValueKey('refresh-${mode.name}'));
        await _reveal(tester, refresh);
        await tester.tap(refresh);
        await tester.pump();
        expect(tester.widget<FilledButton>(refresh).onPressed, isNull);
        expect(find.byKey(ValueKey('status-${mode.name}')), findsOneWidget);
        await tester.pumpAndSettle();
        await _openMode(tester, mode);
      }
      expect(_requests(tester, mode), 1);
      expect(find.widgetWithText(ListTile, 'Tokyo'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pumpAndSettle();
      final afterSearch = mode == ItemsLoadMode.onOpen ? 2 : 1;
      expect(_requests(tester, mode), afterSearch);
      expect(find.widgetWithText(ListTile, 'Paris'), findsNothing);
      await _closeMode(tester, mode);
      await _openMode(tester, mode);
      final afterReopen = afterSearch + (mode == ItemsLoadMode.onOpen ? 1 : 0);
      expect(_requests(tester, mode), afterReopen);
      expect(find.widgetWithText(ListTile, 'Paris'), findsOneWidget);
      await _closeMode(tester, mode);
      final refresh = find.byKey(ValueKey('refresh-${mode.name}'));
      await _reveal(tester, refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      expect(_requests(tester, mode), afterReopen + 1);
      for (final other
          in ItemsLoadMode.values.where((other) => other != mode)) {
        expect(_requests(tester, other), 0);
      }
    });
  }

  testWidgets('leaving while loading ignores the late response',
      (tester) async {
    await _showPage(tester, const LoadingMethodsExamplePage());
    final refresh = find.byKey(const ValueKey('refresh-manual'));
    await _reveal(tester, refresh);
    await tester.tap(refresh);
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pinned example reorders, filters, restores and clears pins',
      (tester) async {
    await _showPage(tester, const PinnedItemsExamplePage());
    Future<void> open() async {
      await _reveal(tester, find.byType(DropdownSearch<String>));
      await tester.tap(find.byType(DropdownSearch<String>));
      await tester.pumpAndSettle();
    }

    Future<void> close() async {
      _smartState(tester).closeDropDownSearch();
      await tester.pumpAndSettle();
    }

    List<String> rows() => tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data!)
        .toList();
    await open();
    await tester.tap(find.byTooltip('Pin Tokyo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pin Paris'));
    await tester.pumpAndSettle();
    expect(rows(), ['Tokyo', 'Paris', 'London', 'Sydney', 'New York']);
    expect(find.text('Pinned'), findsNWidgets(2));
    expect(find.text('Selected value: None'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'London');
    await tester.pumpAndSettle();
    expect(rows(), ['London']);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(rows().take(2), ['Tokyo', 'Paris']);
    await tester.tap(find.byTooltip('Unpin Tokyo'));
    await tester.pumpAndSettle();
    expect(rows(), ['Paris', 'London', 'Tokyo', 'Sydney', 'New York']);
    await tester.tap(find.widgetWithText(ListTile, 'Sydney'));
    await tester.pumpAndSettle();
    expect(find.text('Selected value: Sydney'), findsOneWidget);
    await _press(tester, 'Restart dropdown');
    expect(find.text('Selected value: None'), findsOneWidget);
    await open();
    expect(rows().first, 'Paris');
    await close();
    await tester.pumpWidget(const SizedBox.shrink());
    await _showPage(tester, const PinnedItemsExamplePage());
    await open();
    expect(rows().first, 'Paris');
    await close();
    await _press(tester, 'Clear saved pins');
    expect(find.text('Saved pins cleared for this example.'), findsOneWidget);
    await open();
    expect(rows(), ['London', 'Paris', 'Tokyo', 'Sydney', 'New York']);
    expect(find.text('Pinned'), findsNothing);
    await close();
  });

  testWidgets('pinned example reports clearing failures and restores controls',
      (tester) async {
    await _showPage(tester, const PinnedItemsExamplePage());
    preferences.failClears = true;
    await _press(tester, 'Clear saved pins');
    expect(
        find.text('Could not clear pins. Please try again.'), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Clear saved pins'))
            .onPressed,
        isNotNull);
    preferences.failClears = false;
    await _press(tester, 'Clear saved pins');
    expect(find.text('Saved pins cleared for this example.'), findsOneWidget);
  });

  for (final label in ['Smart selection', 'Loading methods', 'Pinned items']) {
    testWidgets('home selector opens $label', (tester) async {
      await tester.pumpWidget(MyApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownSearch<String>));
      await tester.pumpAndSettle();
      final option = find.widgetWithText(ListTile, label);
      await _reveal(tester, option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Go'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, label), findsOneWidget);
    });
  }

  testWidgets(
      'feature pages fit a narrow screen and keep lower controls reachable',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await _showPage(tester, const SmartSelectionExamplePage());
    await _press(tester, 'Restart dropdown');
    await _press(tester, 'Clear old usage');
    expect(tester.takeException(), isNull);
    await _showPage(tester, const LoadingMethodsExamplePage());
    final refresh = find.byKey(const ValueKey('refresh-onFirstOpen'));
    await _reveal(tester, refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(_requests(tester, ItemsLoadMode.onFirstOpen), 1);
    expect(tester.takeException(), isNull);
    await _showPage(tester, const PinnedItemsExamplePage());
    await _press(tester, 'Restart dropdown');
    await _press(tester, 'Clear saved pins');
    expect(tester.takeException(), isNull);
  });
}

final class _ExamplePreferences extends InMemorySharedPreferencesAsync {
  _ExamplePreferences() : super.empty();

  bool failClears = false;

  @override
  Future<bool> clear(
      ClearPreferencesParameters parameters, SharedPreferencesOptions options) {
    if (failClears) return Future.error(StateError('Could not clear history'));
    return super.clear(parameters, options);
  }
}
