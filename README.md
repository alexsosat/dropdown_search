<h1 align="center">
  Flutter DropdownSearch
  <br>
</h1>

<h4 align="center">
  Simple and highly customizable Flutter Dropdown with a lot of features (search, adaptive, async/sync values, ...) with multi mode like menu, modal, dialog, bottomSheet and etc.
</h4>

<p align="center">
  <a href="https://pub.dev/packages/dropdown_search">
    <img src="https://img.shields.io/badge/build-passing-brightgreen"
         alt="Build">
  </a>
  <a href="https://pub.dev/packages/dropdown_search"><img src="https://img.shields.io/pub/v/dropdown_search"></a>
  <a href="https://www.buymeacoffee.com/SalimDev">
    <img src="https://img.shields.io/badge/$-donate-ff69b4.svg?maxAge=2592000&amp;style=flat">
  </a>
</p>

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/example">Examples</a> •
  <a href="#license">License</a>
</p>

<p align="center">
  <img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/example.gif?raw=true" alt="Dropdown search" />
</p>

## Key Features

* Reactive widget
* Infinite list (lazy loading)
* Sync and/or Async items (online, offline, DB, ...)
* Searchable dropdown
* Support multi level items
* Five dropdown modes: Menu / BottomSheet / ModalBottomSheet / Dialog / autocomplete
* Single & multi selection
* Adaptive platform UI : Material, Adaptive, Cupertino
* Easy customizable UI - No Boilerplate

<br>
<table>
    <tr>
        <td>
            <img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/exa1.png?raw=true" alt="Dropdown search" width="300" />
            <br><br>
            <img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/exa4.gif?raw=true" alt="Dropdown search" width="300" />
        </td>
        <td><img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/exa6.gif?raw=true" alt="Dropdown search" width="300" /></td>
    </tr>
    <tr>
        <td><img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/exa7.gif?raw=true" alt="Dropdown search" width="300" /></td>
        <td>
            <img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/exa3.png?raw=true" alt="Dropdown search" width="300" />
            <br><br>
            <img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/exa5.png?raw=true" alt="Dropdown search" width="300" />
        </td>
    </tr>
</table>


## pubspec.yaml
```yaml
dropdown_search: <lastest version>
```

## Import
```dart
import 'package:dropdown_search/dropdown_search.dart';
```

## Adaptive Platform UI
* To use Material ui (_**by default**_) use `DropdownSearch<T>(...)` or  `DropdownSearch<T>.multiSelection(...)`
* for the cupertino mode use `CupertinoDropdownSearch<T>(...)` or  `CupertinoDropdownSearch<T>.multiSelection(...)`
* To let the package pick the suitable platform UI based on the used platform, use `AdaptiveDropdownSearch<T>(...)` or  `AdaptiveDropdownSearch<T>.multiSelection(...)`


* **_Bonus Tip_**: with adaptive platform ui you can use different `PopupMode` depending on platform type:
```dart
AdaptiveDropdownSearch<T>(
    popupProps: AdaptivePopupProps(
        cupertinoProps: CupertinoPopupProps.bottomSheet(),
        materialProps: PopupProps.dialog()
    ),
)
```

## Pinned Items

Enable `PinnedItemsProps.showPinnedItems` to move pinned rows to the top of the
main popup list, ordered by when they were pinned (oldest first). Unpinned rows
keep their original order, and unpinning restores a row to its original position.
Pinned rows follow the normal search filter; pins stay saved even when a search
or loaded page does not contain them.

Pinned rows use the main list's row builder and click settings. Customize them
through `PopupProps.itemBuilder` using its `isPinned` argument. The former
horizontal-section settings (`scrollProps`, `pinnedItemsAlignment`,
`itemClickProps`, and `pinnedItemsBuilder` on `PinnedItemsProps`) remain accepted
for compatibility but are no longer used.

## Item loading

Choose when to load items with `itemsLoadMode` on either `DropdownSearch` or
`DropdownSearch.multiSelection`:

| Mode | Behavior |
| --- | --- |
| `ItemsLoadMode.onOpen` | Default: load on every popup opening, with the existing search and infinite-scroll behavior. |
| `ItemsLoadMode.manual` | Load only when you explicitly call `loadItems()`. Until then, the popup shows an empty list. |
| `ItemsLoadMode.onFirstOpen` | Load on the first opening and reuse the internal list on later openings. Failed initial loads retry on the next opening; successful empty lists are cached. |

```dart
final dropdownKey = GlobalKey<DropdownSearchState<String>>();

DropdownSearch<String>(
  key: dropdownKey,
  itemsLoadMode: ItemsLoadMode.manual,
  items: (filter, loadProps) => fetchAllItems(),
  popupProps: PopupProps.menu(showSearchBox: true),
);

// Call after the dropdown has mounted, even if its popup is closed.
final items = await dropdownKey.currentState!.loadItems();
```

`loadItems()` replaces the internal list and refreshes an open popup using its
current search text. It works in every mode, returns a copy of the loaded items,
and propagates errors without discarding the last successful list. Concurrent
calls share the pending request. In `onOpen` mode, opening still loads normally
after an explicit load.

`manual` and `onFirstOpen` request the complete list with an empty filter and
null `loadProps`. Searching always filters that list locally using `filterFn`,
`itemAsString`, or the default matching behavior, regardless of `cacheItems` or
`disableFilter`. These modes cannot be combined with `infiniteScrollProps`.

The cache belongs to the dropdown widget's state: it survives popup dismissal
and ordinary rebuilds, including replacing the `items` callback. Call
`loadItems()` to refresh after changing the data source. Changing
`itemsLoadMode` or disposing the dropdown resets the cache. `retrieveItems()`
continues to retrieve results independently and does not populate this cache.
`onItemsLoaded` continues to report results displayed by an open popup; loading
while closed returns results through the `loadItems()` future.

## Smart Selection

Smart selection tracks dated user taps independently of automatic selection.
Automatic selection is off by default; enable it with `autoSelect: true`.
A custom builder can show up to three verified shortcuts inside the popup:

```dart
DropdownSearch<int>(
  items: (filter, loadProps) => [1, 2, 3],
  smartSelectionProps: SmartSelectionProps<int>(
    tag: 'frequent-choice',
    usageRange: const Duration(days: 7),
    autoSelect: true,
    itemToString: (item) => item.toString(),
    itemFromString: int.parse,
    listBuilder: (context, items, selectItem) => Wrap(
      spacing: 8,
      children: items.map((item) => ActionChip(
        label: Text(item.toString()),
        onPressed: () => selectItem(item),
      )).toList(),
    ),
  ),
  popupProps: const PopupProps.dialog(showSearchBox: true),
  onChanged: (item) => print(item),
)
```

The builder appears below the search bar (or at the popup's top when search is
hidden). It receives an immutable list, possibly empty. Shortcuts remain visible
while searching, select through normal callbacks, and count as user taps.
They are ranked by in-range count, then most recent usage, then identifier.
Tracking and shortcuts work with `autoSelect: false` too.

Original item loading verifies both shortcuts and automatic selection. Smart
selection makes no extra item requests: manual mode waits for `loadItems()`,
while on-open and first-open modes can verify during popup opening. Loaded
objects are used for display and selection. Only a complete, successful,
unfiltered source list removes missing items from history; filtered results,
partial pages, and load failures never prove that an item was deleted.
Disabled or unrestorable items are excluded from shortcuts.

Identifiers must be stable and unique. Dropdowns sharing a tag share history
and must represent the same underlying collection. Counts use UTC timestamps
and the inclusive interval from `now - usageRange` through `now`. Out-of-window
history remains available for a wider future range until explicitly cleared
or removed because its item is absent from the complete original list.

With `autoSelect: true`, the initial selection waits for a confirmed, unique
winner and respects `onBeforeChange` and `onChanged`. Tied leaders do not
auto-select. Explicit values take precedence. Explicit selection changes,
configuration changes, disposal, and relevant cache clearing cancel a pending
automatic selection; opening the popup itself does not. Existing callers must
opt in explicitly to retain automatic selection.

Enabled item taps count even when repeating a selection or when
`onBeforeChange` rejects the change. Programmatic changes, automatic selections,
and pin controls do not count. Gestures owned by the caller through
`interceptCallBacks` are not tracked. Multi-selection does not support smart
selection. Mounted builders sharing a tag refresh after successful history
changes, cache clearing, and original-source updates.

### Suggested items below the field

`PopupProps.suggestedItemProps.suggestedItems` accepts an independent `List<T>`
(default: empty). Suggestions appear below the complete FormField (or custom
field) on the first frame, without loading or opening the dropdown. Rebuild
the widget with a new list to update them. Migrate callbacks such as
`suggestedItems: (items) => items.take(3).toList()` to an explicit list such as
`suggestedItems: [1, 2, 3]`. Default and custom `suggestedItemBuilder`
widgets keep their scrolling, alignment, and click settings. Tapping a
suggestion selects directly without opening the popup; multi-selection toggles
the item through the normal selection callbacks. Single-selection suggestion
taps also count toward smart-selection history.

### Clearing saved dropdown history

```dart
await DropdownSearchCache.clearSmartSelection(tag: 'frequent-choice');
await DropdownSearchCache.clearPinnedItems(tag: 'my-pins');
await DropdownSearchCache.clearAll();
```

Each method accepts an optional `tag`. Omit it to clear every tag for that cache
type. `clearAll(tag: 'example')` clears that tag in both namespaces. Awaiting the
future ensures earlier pending writes have finished and the requested history
has been removed; clearing failures are returned through the future.

To remove only old usage while retaining recent counts, pass a positive
`olderThan` duration to `clearSmartSelection` or `clearAll`:

```dart
await DropdownSearchCache.clearSmartSelection(
  tag: 'frequent-choice',
  olderThan: const Duration(days: 7),
);
await DropdownSearchCache.clearAll(olderThan: const Duration(days: 30));
```

Only records strictly before `now - olderThan` are removed. Records at the
cutoff, recent usage, and future-dated records are preserved. Empty histories
are removed. In this mode `clearAll` preserves pinned items, which have no
expiration date. Omitting `olderThan` retains the full-clear behavior above.
Choose a retention duration long enough for every usage range sharing a tag;
deleted records cannot be recovered if a wider range is used later.

Clearing preserves current selections and pins displayed in already-open
popups. Reopening a popup reloads its cleared pin history, and future dropdown
initializations use the cleared smart-selection history. Item-provider caches
and unrelated shared preferences are preserved. Persistence operations are
serialized within the current isolate.

## Infinite Scroll
To enable infinite scroll all you have to do is to declare `infiniteScrollProps` and of course don't forget to pass `loadProps` to your API like this:
```dart
DropdownSearch<T>(
    items: (filter, loadProps) => _getDataFromAPI(filter, loadProps!.skip, loadProps!.take),
    popupProps: PopupProps.dialog(
        infiniteScrollProps: InfiniteScrollProps(
            loadProps: LoadProps(skip: 0, take: 10),
        ),
    ),
)
```


## Simple implementation
<details><summary>See here</summary>

```dart
DropdownSearch<String>(
  items: (f, cs) => ["Item 1", 'Item 2', 'Item 3', 'Item 4'],
  popupProps: PopupProps.menu(
    disabledItemFn: (item) => item == 'Item 3',
    fit: FlexFit.loose
  ),
),
```
<img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/exa1.png?raw=true" alt="Dropdown search" width="400" />



```dart
DropdownSearch<String>.multiSelection(
  mode: Mode.CUSTOM,
  items: (f, cs) => ["Monday", 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
  dropdownBuilder: (ctx, selectedItem) => Icon(Icons.calendar_month_outlined, size: 54),
),
```
<img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/exa2.png?raw=true" alt="Dropdown search" width="400" />


```dart
DropdownSearch<(String, Color)>(
  clickProps: ClickProps(borderRadius: BorderRadius.circular(20)),
  mode: Mode.CUSTOM,
  items: (f, cs) => [
    ("Red", Colors.red),
    ("Black", Colors.black),
    ("Yellow", Colors.yellow),
    ('Blue', Colors.blue),
  ],
  compareFn: (item1, item2) => item1.$1 == item2.$1,
  popupProps: PopupProps.menu(
  menuProps: MenuProps(align: MenuAlign.bottomCenter),
    fit: FlexFit.loose,
    itemBuilder: (context, item, isDisabled, isSelected) => Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(item.$1, style: TextStyle(color: item.$2, fontSize: 16)),
    ),
  ),
  dropdownBuilder: (ctx, selectedItem) => Icon(Icons.face, color: selectedItem?.$2, size: 54),
),
```
<img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/exa4.gif?raw=true" alt="Dropdown search" width="400" />

```dart
DropdownSearch<(IconData, String)>(
  selectedItem: (Icons.person, 'Your Profile'),
  compareFn: (item1, item2) => item1.$1 == item2.$2,
  items: (f, cs) => [
    (Icons.person, 'Your Profile'),
    (Icons.settings, 'Setting'),
    (Icons.lock_open_rounded, 'Change Password'),
    (Icons.power_settings_new_rounded, 'Logout'),
  ],
  decoratorProps: DropDownDecoratorProps(
    decoration: InputDecoration(
      contentPadding: EdgeInsets.symmetric(vertical: 6),
      filled: true,
      fillColor: Color(0xFF1eb98f),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
  dropdownBuilder: (context, selectedItem) {
    return ListTile(
      leading: Icon(selectedItem!.$1, color: Colors.white),
      title: Text(
        selectedItem.$2,
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  },
  popupProps: PopupProps.menu(
    itemBuilder: (context, item, isDisabled, isSelected) {
      return ListTile(
        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        leading: Icon(item.$1, color: Colors.white),
        title: Text(
          item.$2,
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    },
    fit: FlexFit.loose,
    menuProps: MenuProps(
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.only(top: 16),
    ),
    containerBuilder: (ctx, popupWidget) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Image.asset(
              'assets/images/arrow-up.png',
              color: Color(0xFF1eb98f),
              height: 14,
            ),
          ),
          Flexible(
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFF1eb98f),
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: popupWidget,
            ),
          ),
        ],
      );
    },
  ),
),
```
<img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/exa3.png?raw=true" alt="Dropdown search" width="400" />


```dart
DropdownSearch<String>(
  items: (filter, infiniteScrollProps) => ['Item 1', 'Item 2', 'Item 3'],
  suffixProps: DropdownSuffixProps(
    dropdownButtonProps: DropdownButtonProps(
      iconClosed: Icon(Icons.keyboard_arrow_down),
      iconOpened: Icon(Icons.keyboard_arrow_up),
    ),
  ),
  decoratorProps: DropDownDecoratorProps(
    textAlign: TextAlign.center,
    decoration: InputDecoration(
      contentPadding: EdgeInsets.symmetric(vertical: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.transparent),
        borderRadius: BorderRadius.circular(12),
      ),
      hintText: 'Please select...',
      hintStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.grey),
    ),
  ),
  popupProps: PopupProps.menu(
    itemBuilder: (context, item, isDisabled, isSelected) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Text(
          item,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      );
    },
    constraints: BoxConstraints(maxHeight: 160),
    menuProps: MenuProps(
      margin: EdgeInsets.only(top: 12),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
  ),
),
```
<img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/exa5.png?raw=true" alt="Dropdown search" width="400" />


````dart
DropdownSearch<UserModel>.multiSelection(
  items: (filter, s) => getData(filter),
  compareFn: (i, s) => i.isEqual(s),
  popupProps: PopupPropsMultiSelection.bottomSheet(
    bottomSheetProps: BottomSheetProps(backgroundColor: Colors.blueGrey[50]),
    showSearchBox: true,
    itemBuilder: userModelPopupItem,
    suggestedItemProps: SuggestedItemProps(
      showSuggestedItems: true,
      suggestedItems: UserModel.suggestedUsers,
    ),
  ),
),
````
<img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/exa6.gif?raw=true" alt="Dropdown search" width="400" />


````dart
DropdownSearch<int>(
  items: (f, cs) => List.generate(30, (i) => i + 1),
  decoratorProps: DropDownDecoratorProps(
    decoration: InputDecoration(labelText: "Dialog with title", hintText: "Select an Int"),
  ),
  popupProps: PopupProps.dialog(
    title: Container(
      decoration: BoxDecoration(color: Colors.deepPurple),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Text(
        'Numbers 1..30',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Colors.white70),
      ),
    ),
    dialogProps: DialogProps(
      clipBehavior: Clip.antiAlias,
      shape: OutlineInputBorder(
        borderSide: BorderSide(width: 0),
        borderRadius: BorderRadius.circular(25),
      ),
    ),
  ),
),
````
<img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/exa7.gif?raw=true" alt="Dropdown search" width="400" />

</details>

## Layout customization
You can customize the layout of the DropdownSearch and its items. click [here](https://github.com/salim-lachdhaf/searchable_dropdown/tree/master/example) for more examples.

Full documentation [here](https://pub.dev/documentation/dropdown_search/latest/dropdown_search/DropdownSearch-class.html)

<details><summary>DropdownSearch Anatomy</summary>
    <img src="https://github.com/salim-lachdhaf/searchable_dropdown/blob/master/screenshots/anatomy.png?raw=true" alt="Dropdown search" width="800" />
</details>


## Support

If this plugin was useful to you, helped you to deliver your app, saved you a lot of time, or you just want to support the project, I would be very grateful if you buy me a cup of coffee.

<a href="https://www.buymeacoffee.com/SalimDev" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/purple_img.png" alt="Buy Me A Coffee" style="height: 41px !important;width: 174px !important;box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;-webkit-box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;" ></a>

## License

MIT
