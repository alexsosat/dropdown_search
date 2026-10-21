import 'dart:convert';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:dropdown_search/src/data/data_sources/pinned_items_database.dart';
import 'package:dropdown_search/src/data/data_sources/smart_selection_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/history_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = HistoryPreferences();
  final history = SmartSelectionDatabase();
  final pins = PinnedItemsDatabase();
  final now = DateTime.utc(2026, 10, 19, 12);
  const week = Duration(days: 7);

  setUpAll(() async {
    SharedPreferencesAsyncPlatform.instance = backend;
    await PinnedItemsDatabase.init();
  });

  setUp(() async {
    backend.failReads = false;
    backend.failWrites = false;
    backend.failSmartClear = false;
    await DropdownSearchCache.clearAll();
  });

  Future<void> click(String item, {DateTime? at, String tag = 'a'}) =>
      history.recordClick(tag: tag, item: item, at: at ?? now);

  Future<String?> winner({String tag = 'a', Duration range = week}) =>
      history.mostUsed(tag: tag, usageRange: range, now: now);

  test('records dated counts and recomputes them for different rolling windows',
      () async {
    for (var i = 0; i < 3; i++) {
      await click('old', at: now.subtract(const Duration(days: 10)));
    }
    await click('old');
    await click('recent');
    await click('recent');
    expect(await winner(), 'recent');
    expect(await winner(range: const Duration(days: 30)), 'old');

    final stored = jsonDecode((await SharedPreferencesAsync()
        .getString('dropdown_search:smart_selection:a'))!) as Map;
    expect(stored['recent'], [
      {'at': now.microsecondsSinceEpoch, 'count': 2}
    ]);
  });

  test('interval includes both boundaries and excludes future and older taps',
      () async {
    final start = now.subtract(week);
    await click('included', at: start);
    await click('included', at: now);
    for (var i = 0; i < 3; i++) {
      await click('excluded',
          at: start.subtract(const Duration(microseconds: 1)));
      await click('excluded', at: now.add(const Duration(microseconds: 1)));
    }
    expect(await winner(), 'included');
  });

  test('empty windows and tied leaders have no winner', () async {
    expect(await winner(), isNull);
    await click('one', at: now.subtract(const Duration(days: 20)));
    expect(await winner(), isNull);
    await click('one');
    expect(await winner(), 'one');
    await click('two');
    expect(await winner(), isNull);
    await click('two');
    expect(await winner(), 'two');
  });

  test('rejects nonpositive windows', () {
    expect(
        () => SmartSelectionProps<int>(
            tag: 'a',
            usageRange: Duration.zero,
            itemToString: (item) => '$item',
            itemFromString: int.parse),
        throwsArgumentError);
    expect(() => winner(range: Duration.zero), throwsArgumentError);
    expect(() => winner(range: const Duration(days: -1)), throwsArgumentError);
  });

  test('ignores malformed history and individual invalid count records',
      () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString('dropdown_search:smart_selection:a', '{invalid');
    expect(await winner(), isNull);
    await prefs.setString(
        'dropdown_search:smart_selection:a',
        jsonEncode({
          'bad': [
            {'at': now.microsecondsSinceEpoch, 'count': -2},
            {'at': 'yesterday', 'count': 100},
            {'at': now.microsecondsSinceEpoch, 'count': 1.5},
            null,
          ],
          'valid': [
            {'at': now.microsecondsSinceEpoch, 'count': 2}
          ],
        }));
    expect(await winner(), 'valid');
    await click('valid');
    expect(await winner(), 'valid');
  });

  test('rapid writes from separate instances share counts without lost updates',
      () async {
    await Future.wait(List.generate(
        30,
        (_) => SmartSelectionDatabase()
            .recordClick(tag: 'a', item: 'shared', at: now)));
    final stored = jsonDecode((await SharedPreferencesAsync()
        .getString('dropdown_search:smart_selection:a'))!) as Map;
    expect(stored['shared'], [
      {'at': now.microsecondsSinceEpoch, 'count': 30}
    ]);
  });

  final clearers = <String, Future<void> Function({String? tag})>{
    'smart': DropdownSearchCache.clearSmartSelection,
    'pins': DropdownSearchCache.clearPinnedItems,
    'all': DropdownSearchCache.clearAll,
  };
  for (final entry in clearers.entries) {
    for (final tag in <String?>[null, 'a']) {
      test('${entry.key} clears ${tag ?? 'every tag'} and isolates namespaces',
          () async {
        final prefs = SharedPreferencesAsync();
        await prefs.setString('unrelated', 'preserved');
        for (final name in ['a', 'b']) {
          await click('value', tag: name);
          await pins.addItem(tag: name, item: 'value');
        }
        await entry.value(tag: tag);
        for (final name in ['a', 'b']) {
          final targeted = tag == null || tag == name;
          expect(await winner(tag: name),
              targeted && entry.key != 'pins' ? isNull : 'value');
          expect(pins.get(name),
              targeted && entry.key != 'smart' ? isEmpty : ['value']);
        }
        expect(await prefs.getString('unrelated'), 'preserved');
      });
    }
  }

  test('global clearing finds orphaned namespace entries and removes indexes',
      () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setStringList('dropdown_search:pinned_items:orphan', ['value']);
    await prefs.setString('dropdown_search:smart_selection:orphan', '{}');
    await pins.addItem(tag: 'a', item: 'value');
    await DropdownSearchCache.clearAll();
    expect(
        (await prefs.getKeys())
            .where((key) => key.startsWith('dropdown_search:')),
        isEmpty);
    expect(await pins.getTags(), isEmpty);
  });

  test('clearing waits for earlier writes and permits subsequent new history',
      () async {
    final writes = <Future<void>>[];
    for (var i = 0; i < 10; i++) {
      writes.add(click('old'));
      writes.add(pins.addItem(tag: 'a', item: '$i'));
    }
    final clear = DropdownSearchCache.clearAll();
    await Future.wait([...writes, clear]);
    expect(await winner(), isNull);
    expect(pins.get('a'), isEmpty);
    await click('new');
    await pins.addItem(tag: 'a', item: 'new');
    expect(await winner(), 'new');
    expect(pins.get('a'), ['new']);
  });

  test('failed writes do not block the persistence queue', () async {
    backend.failWrites = true;
    await expectLater(click('failed'), throwsStateError);
    backend.failWrites = false;
    await click('recovered');
    expect(await winner(), 'recovered');
  });

  test('age-based clearing preserves cutoff, recent and future dated counts',
      () async {
    final cutoff = now.subtract(week);
    await click('mixed', at: cutoff.subtract(const Duration(microseconds: 1)));
    await click('mixed', at: cutoff);
    await click('mixed', at: cutoff);
    await click('mixed');
    await click('mixed', at: now.add(const Duration(days: 1)));
    await click('expired-only', at: now.subtract(const Duration(days: 30)));

    await history.clear(tag: 'a', olderThan: week, now: now);
    final prefs = SharedPreferencesAsync();
    final stored = await prefs.getString('dropdown_search:smart_selection:a');
    expect(jsonDecode(stored!), {
      'mixed': [
        {'at': cutoff.microsecondsSinceEpoch, 'count': 2},
        {'at': now.microsecondsSinceEpoch, 'count': 1},
        {
          'at': now.add(const Duration(days: 1)).microsecondsSinceEpoch,
          'count': 1
        },
      ],
    });
    expect(await winner(), 'mixed');
    await history.clear(tag: 'a', olderThan: week, now: now);
    expect(await prefs.getString('dropdown_search:smart_selection:a'), stored);
  });

  final ageClearers =
      <String, Future<void> Function({String? tag, Duration? olderThan})>{
    'smart': DropdownSearchCache.clearSmartSelection,
    'all': DropdownSearchCache.clearAll,
  };
  for (final entry in ageClearers.entries) {
    for (final tag in <String?>[null, 'a']) {
      test(
          '${entry.key} age-based clear targets ${tag ?? 'all tags'} and keeps pins',
          () async {
        final prefs = SharedPreferencesAsync();
        await prefs.setString('unrelated', 'preserved');
        final recent = DateTime.now().subtract(const Duration(minutes: 1));
        final old = recent.subtract(const Duration(days: 30));
        for (final name in ['a', 'b']) {
          await click('old', tag: name, at: old);
          await click('recent', tag: name, at: recent);
          await pins.addItem(tag: name, item: 'pin');
        }
        await entry.value(tag: tag, olderThan: week);
        for (final name in ['a', 'b']) {
          final stored = jsonDecode((await prefs
              .getString('dropdown_search:smart_selection:$name'))!) as Map;
          expect(stored.keys.toSet(),
              tag == null || tag == name ? {'recent'} : {'old', 'recent'});
          expect(pins.get(name), ['pin']);
        }
        expect(await prefs.getString('unrelated'), 'preserved');
      });
    }

    test('${entry.key} rejects invalid retention before modifying either cache',
        () async {
      await click('old', at: DateTime.now().subtract(const Duration(days: 30)));
      await pins.addItem(tag: 'a', item: 'pin');
      final prefs = SharedPreferencesAsync();
      final before = await prefs.getAll();
      for (final invalid in [Duration.zero, const Duration(days: -1)]) {
        await expectLater(
            Future<void>.sync(() => entry.value(olderThan: invalid)),
            throwsArgumentError);
        expect(await prefs.getAll(), before);
        expect(pins.get('a'), ['pin']);
      }
    });
  }

  test(
      'age-based clearing removes empty, malformed and fully expired histories',
      () async {
    final prefs = SharedPreferencesAsync();
    await click('expired', at: now.subtract(const Duration(days: 30)));
    await prefs.setString('dropdown_search:smart_selection:empty', '{}');
    await prefs.setString('dropdown_search:smart_selection:invalid', 'invalid');
    await history.clear(olderThan: week, now: now);
    expect(
        (await prefs.getKeys())
            .where((key) => key.startsWith('dropdown_search:smart_selection:')),
        isEmpty);
    await history.clear(olderThan: week, now: now);
    await history.clear(tag: 'missing', olderThan: week, now: now);
  });

  test('age-based clearing orders pending writes and permits new history',
      () async {
    final writes = [
      click('mixed', at: now.subtract(const Duration(days: 30))),
      click('mixed'),
      click('mixed'),
    ];
    final clearing = history.clear(olderThan: week, now: now);
    await Future.wait([...writes, clearing]);
    final prefs = SharedPreferencesAsync();
    final stored = jsonDecode(
        (await prefs.getString('dropdown_search:smart_selection:a'))!) as Map;
    expect(stored['mixed'], [
      {'at': now.microsecondsSinceEpoch, 'count': 2}
    ]);
    await click('mixed');
    expect(await winner(), 'mixed');
  });

  test('age-based clearing reports read, rewrite and removal failures',
      () async {
    await click('mixed', at: now.subtract(const Duration(days: 30)));
    await click('mixed');
    backend.failReads = true;
    await expectLater(
        history.clear(olderThan: week, now: now), throwsStateError);
    backend.failReads = false;
    backend.failWrites = true;
    await expectLater(
        history.clear(olderThan: week, now: now), throwsStateError);
    backend.failWrites = false;
    await history.clear(olderThan: week, now: now);
    expect(await winner(), 'mixed');
    await click('expired',
        tag: 'old-only', at: now.subtract(const Duration(days: 30)));
    backend.failSmartClear = true;
    await expectLater(history.clear(tag: 'old-only', olderThan: week, now: now),
        throwsStateError);
    backend.failSmartClear = false;
    await history.clear(tag: 'old-only', olderThan: week, now: now);
  });

  test('clearAll attempts both clears and reports failures', () async {
    await click('value');
    await pins.addItem(tag: 'a', item: 'value');
    backend.failSmartClear = true;
    await expectLater(DropdownSearchCache.clearAll(), throwsStateError);
    expect(pins.get('a'), isEmpty);
    backend.failSmartClear = false;
    await DropdownSearchCache.clearAll();
    expect(await winner(), isNull);
  });
}
