library dropdown_search;

import 'dart:async';
import 'src/data/data_sources/dropdown_cache_storage.dart';
import 'src/data/data_sources/smart_selection_database.dart';
import 'src/properties/smart_selection_props.dart';
import 'package:dropdown_search/src/properties/dropdown_props.dart';
import 'package:dropdown_search/src/properties/infinite_scroll_props.dart';
import 'package:dropdown_search/src/properties/scroll_props.dart';
import 'package:dropdown_search/src/utils.dart';
import 'package:dropdown_search/src/widgets/custom_icon_button.dart';
import 'package:dropdown_search/src/widgets/custom_inkwell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/properties/dropdown_suffix_props.dart';
import 'src/properties/items_load_mode.dart';
import 'src/properties/popup_props.dart';
import 'src/items_loader.dart';
import 'src/dropdown_source.dart';
import 'src/widgets/custom_scroll_view.dart';
import 'src/widgets/popup_menu.dart';
import 'src/widgets/dropdown_search_popup.dart';

export 'src/properties/bottom_sheet_props.dart';
export 'src/properties/clear_button_props.dart';
export 'src/properties/dialog_props.dart';
export 'src/properties/dropdown_props.dart';
export 'src/properties/suggested_item_props.dart';
export 'src/properties/pinned_items_props.dart';
export 'src/properties/smart_selection_props.dart';
export 'src/dropdown_search_cache.dart';
export 'src/properties/icon_button_props.dart';
export 'src/properties/item_props.dart';
export 'src/properties/list_view_props.dart';
export 'src/properties/menu_props.dart';
export 'src/properties/modal_bottom_sheet_props.dart';
export 'src/properties/popup_props.dart';
export 'src/properties/scrollbar_props.dart';
export 'src/properties/text_field_props.dart';
export 'src/properties/infinite_scroll_props.dart';
export 'src/properties/items_load_mode.dart';
export 'src/properties/scroll_props.dart';
export 'src/widgets/dropdown_search_popup.dart';
export 'src/properties/dropdown_suffix_props.dart';

typedef DropdownSearchOnFind<T> = FutureOr<List<T>> Function(
    String filter, LoadProps? loadProps);
typedef DropdownSearchItemAsString<T> = String Function(T item);
typedef DropdownSearchFilterFn<T> = bool Function(T item, String filter);
typedef DropdownSearchCompareFn<T> = bool Function(T item1, T item2);
typedef DropdownSearchBuilder<T> = Widget Function(
    BuildContext context, T? selectedItem);
typedef DropdownSearchBuilderMultiSelection<T> = Widget Function(
    BuildContext context, List<T> selectedItems);
typedef DropdownSearchPopupItemBuilder<T> = Widget Function(
    BuildContext context,
    T item,
    bool isDisabled,
    bool isSelected,
    bool isPinned);
typedef DropdownSearchPopupItemEnabled<T> = bool Function(T item);
typedef ErrorBuilder<T> = Widget Function(
    BuildContext context, String searchEntry, dynamic exception);
typedef EmptyBuilder<T> = Widget Function(
    BuildContext context, String searchEntry);
typedef LoadingBuilder<T> = Widget Function(
    BuildContext context, String searchEntry);
typedef BeforeChange<T> = Future<bool?> Function(T? prevItem, T? nextItem);
typedef BeforePopupOpening<T> = Future<bool?> Function(T? selectedItem);
typedef BeforePopupOpeningMultiSelection<T> = Future<bool?> Function(
    List<T> selectedItem);
typedef BeforeChangeMultiSelection<T> = Future<bool?> Function(
    List<T> prevItems, List<T> nextItems);
typedef FavoriteItemsBuilder<T> = Widget Function(
    BuildContext context, T item, bool isSelected);
typedef ValidationMultiSelectionBuilder<T> = Widget Function(
    BuildContext context, List<T> items);
typedef PositionCallback = RelativeRect Function(
    RenderBox dropdownBox, RenderBox overlay);
typedef OnItemAdded<T> = void Function(List<T> selectedItems, T addedItem);
typedef OnItemRemoved<T> = void Function(List<T> selectedItems, T removedItem);
typedef PopupBuilder<T> = Widget Function(
    BuildContext context, Widget popupWidget);

/// Transformer to parse from a String to a T
typedef PinnedItemsEntityTransformer<T> = T Function(String item);

/// Transformer to parse from a String to a List of T
typedef PinnedItemsStringTransformer<T> = String Function(T item);

enum PopupMode { dialog, modalBottomSheet, menu, bottomSheet }

enum Mode { form, /*autoComplete,*/ custom }

class DropdownSearch<T> extends StatefulWidget {
  ///selected items
  final List<T> selectedItems;

  ///items/data
  final DropdownSearchOnFind<T>? items;

  /// Controls automatic loading and caching across popup openings.
  /// Cached modes always search locally and cannot use infinite scrolling.
  /// Use [DropdownSearchState.loadItems] to load or refresh explicitly.
  final ItemsLoadMode itemsLoadMode;

  /// Tracks recent usage and optionally builds popup shortcuts or auto-selects
  /// a verified initial value after normal original-item loading.
  /// Only available in single-selection mode; explicit selections take priority.
  final SmartSelectionProps<T>? smartSelectionProps;

  ///called when a new item is selected
  final ValueChanged<T?>? onChanged;

  ///called when a new items are selected
  final ValueChanged<List<T>>? onChangedMultiSelection;

  ///to customize list of items UI
  final DropdownSearchBuilder<T>? dropdownBuilder;

  ///to customize list of items UI in MultiSelection mode
  final DropdownSearchBuilderMultiSelection<T>? dropdownBuilderMultiSelection;

  /// scroll props for selected item on the dropdown.
  /// example :
  /// ```dart
  ///   SizedBox(
  ///        height: 50,
  ///       child: DropdownSearch<int>.multiSelection(
  ///               items: (f, cs) => [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
  ///               selectedItemsScrollProps: ScrollProps(),
  ///         ),
  ///    ),
  ///```
  final ScrollProps? selectedItemsScrollProps;

  ///customize the fields the be shown
  final DropdownSearchItemAsString<T>? itemAsString;

  ///	custom filter function
  final DropdownSearchFilterFn<T>? filterFn;

  ///enable/disable dropdownSearch
  final bool enabled;

  ///function that compares two object with the same type to detected if it's the selected item or not
  final DropdownSearchCompareFn<T>? compareFn;

  /// Used to configure the auto validation of [FormField] and [Form] widgets.
  final AutovalidateMode? autoValidateMode;

  /// An optional method to call with the final value when the form is saved via
  final FormFieldSetter<T>? onSaved;

  /// An optional method to call with the final value when the form is saved via
  final FormFieldSetter<List<T>>? onSavedMultiSelection;

  /// An optional method that validates an input. Returns an error string to
  /// display if the input is invalid, or null otherwise.
  final FormFieldValidator<T>? validator;

  /// An optional method that validates an input. Returns an error string to
  /// display if the input is invalid, or null otherwise.
  final FormFieldValidator<List<T>>? validatorMultiSelection;

  /// callback executed before applying value change
  final BeforeChange<T>? onBeforeChange;

  /// callback executed before applying values changes
  final BeforeChangeMultiSelection<T>? onBeforeChangeMultiSelection;

  ///define whatever we are in multi selection mode or single selection mode
  final bool isMultiSelectionMode;

  ///custom suffix widget props
  final DropdownSuffixProps suffixProps;

  ///dropdown click properties
  final ClickProps clickProps;

  ///custom props to single mode popup
  final PopupPropsMultiSelection<T> popupProps;

  ///dropdown decoration props
  final DropDownDecoratorProps decoratorProps;

  ///a callBack will be called before opening le popup
  ///if the callBack return FALSE, the opening of the popup will be cancelled
  final BeforePopupOpening<T>? onBeforePopupOpening;

  ///a callBack will be called before opening le popup
  ///if the callBack return FALSE, the opening of the popup will be cancelled
  final BeforePopupOpeningMultiSelection<T>? onBeforePopupOpeningMultiSelection;

  final Mode mode;

  DropdownSearch({
    super.key,
    T? selectedItem,
    this.mode = Mode.form,
    this.autoValidateMode = AutovalidateMode.disabled,
    this.onChanged,
    this.items,
    this.itemsLoadMode = ItemsLoadMode.onOpen,
    this.smartSelectionProps,
    this.dropdownBuilder,
    this.suffixProps = const DropdownSuffixProps(),
    this.clickProps = const ClickProps(),
    this.enabled = true,
    this.filterFn,
    this.itemAsString,
    this.compareFn,
    this.onBeforeChange,
    this.onBeforePopupOpening,
    PopupProps<T> popupProps = const PopupProps.menu(),
    //form properties
    this.onSaved,
    this.validator,
    DropDownDecoratorProps? decoratorProps,
  })  : assert(
          itemsLoadMode == ItemsLoadMode.onOpen ||
              popupProps.infiniteScrollProps == null,
          'Cached item loading modes cannot use infiniteScrollProps',
        ),
        assert(
          T == String || T == int || T == double || compareFn != null,
          '`compareFn` is required',
        ),
        assert(
          mode != Mode.custom || dropdownBuilder != null,
          'Please implement your `dropdownBuilder`',
        ),
        assert(
          mode != Mode.custom ||
              (decoratorProps == null && onSaved == null && validator == null),
          'Custom mode has no form properties',
        ),
        decoratorProps = decoratorProps ?? const DropDownDecoratorProps(),
        selectedItems = _itemToList(selectedItem),
        popupProps = PopupPropsMultiSelection.from(popupProps),
        isMultiSelectionMode = false,
        dropdownBuilderMultiSelection = null,
        validatorMultiSelection = null,
        onBeforeChangeMultiSelection = null,
        onSavedMultiSelection = null,
        onChangedMultiSelection = null,
        onBeforePopupOpeningMultiSelection = null,
        selectedItemsScrollProps = null;

  const DropdownSearch.multiSelection({
    super.key,
    this.mode = Mode.form,
    this.autoValidateMode = AutovalidateMode.disabled,
    this.items,
    this.itemsLoadMode = ItemsLoadMode.onOpen,
    this.suffixProps = const DropdownSuffixProps(),
    this.clickProps = const ClickProps(),
    this.enabled = true,
    this.filterFn,
    this.itemAsString,
    this.compareFn,
    this.selectedItems = const [],
    this.popupProps = const PopupPropsMultiSelection.menu(),
    this.selectedItemsScrollProps,
    ValueChanged<List<T>>? onChanged,
    BeforeChangeMultiSelection<T>? onBeforeChange,
    BeforePopupOpeningMultiSelection<T>? onBeforePopupOpening,
    DropdownSearchBuilderMultiSelection<T>? dropdownBuilder,
    //form properties
    FormFieldSetter<List<T>>? onSaved,
    FormFieldValidator<List<T>>? validator,
    DropDownDecoratorProps? decoratorProps,
  })  : assert(
          T == String || T == int || T == double || compareFn != null,
          '`compareFn` is required',
        ),
        assert(
          mode != Mode.custom || dropdownBuilder != null,
          'Please implement your `dropdownBuilder`',
        ),
        assert(
          mode != Mode.custom ||
              (decoratorProps == null && onSaved == null && validator == null),
          "Custom mode has no form properties",
        ),
        decoratorProps = decoratorProps ?? const DropDownDecoratorProps(),
        onChangedMultiSelection = onChanged,
        onBeforePopupOpeningMultiSelection = onBeforePopupOpening,
        onSavedMultiSelection = onSaved,
        onBeforeChangeMultiSelection = onBeforeChange,
        validatorMultiSelection = validator,
        dropdownBuilderMultiSelection = dropdownBuilder,
        isMultiSelectionMode = true,
        dropdownBuilder = null,
        validator = null,
        onBeforeChange = null,
        onSaved = null,
        onChanged = null,
        smartSelectionProps = null,
        onBeforePopupOpening = null;

  static List<T> _itemToList<T>(T? item) {
    List<T?> nullableList = List.filled(1, item);
    return nullableList.whereType<T>().toList();
  }

  @override
  DropdownSearchState<T> createState() => DropdownSearchState<T>();
}

class DropdownSearchState<T> extends State<DropdownSearch<T>> {
  final ValueNotifier<List<T>> _selectedItemsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isFocused = ValueNotifier(false);
  final _popupStateKey = GlobalKey<DropdownSearchPopupState<T>>();
  late final ItemsLoader<T> _itemsLoader;
  int _smartSelectionRevision = 0;
  int _smartQueryRevision = 0;
  int _smartHistoryRevision = 0;
  int _lastSourceLoaderRevision = -1;
  int _startupSmartCacheRevision = 0;
  bool _smartAutoAttempted = false;
  final _source = DropdownSource<T>();
  final _suggestedItems = ValueNotifier<List<T>>([]);
  late final ValueNotifier<SmartSelectionPresentation<T>> _smartPresentation;
  StreamSubscription<String?>? _smartSubscription;

  void _validateItemsLoadMode() {
    if (widget.itemsLoadMode != ItemsLoadMode.onOpen &&
        widget.popupProps.infiniteScrollProps != null) {
      throw ArgumentError(
        'Cached item loading modes cannot use infiniteScrollProps',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _itemsLoader = ItemsLoader<T>(
      () =>
          widget.items?.call(
            '',
            widget.itemsLoadMode == ItemsLoadMode.onOpen
                ? widget.popupProps.infiniteScrollProps?.loadProps
                : null,
          ) ??
          <T>[],
      widget.itemsLoadMode,
    );
    _validateItemsLoadMode();
    _itemsLoader.addListener(_onOwnerItemsLoaded);
    _source.addListener(_onSourceChanged);
    _smartPresentation = ValueNotifier(SmartSelectionPresentation<T>(
        items: [], builder: widget.smartSelectionProps?.listBuilder));
    final tag = widget.smartSelectionProps?.tag;
    if (tag != null) {
      _startupSmartCacheRevision = DropdownCacheStorage.smartRevision(tag);
    }
    _smartSubscription = DropdownCacheStorage.smartChanges.listen((tag) {
      if (mounted && (tag == null || tag == widget.smartSelectionProps?.tag)) {
        _smartHistoryRevision++;
        _refreshSmartItems();
      }
    });
    _selectedItemsNotifier.value = List.from(widget.selectedItems);
    _updateSuggestedItems();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshSmartItems();
    });
  }

  void _onOwnerItemsLoaded() {
    final loader = _itemsLoader;
    if (!mounted ||
        loader.isLoading ||
        !loader.hasLoaded ||
        loader.error != null ||
        loader.revision == _lastSourceLoaderRevision) {
      return;
    }
    _lastSourceLoaderRevision = loader.revision;
    final pagination = widget.popupProps.infiniteScrollProps?.loadProps;
    final prefix = pagination == null ||
        loader.mode != ItemsLoadMode.onOpen ||
        pagination.skip == 0;
    _source.publish(loader.items,
        completePrefix: prefix,
        complete: prefix &&
            (pagination == null ||
                loader.mode != ItemsLoadMode.onOpen ||
                loader.items.length < pagination.take));
  }

  void _onSourceChanged() {
    Future.microtask(() {
      if (!mounted) return;
      _refreshSmartItems();
    });
  }

  void _updateSuggestedItems() {
    final props = widget.popupProps.suggestedItemProps;
    _suggestedItems.value = List<T>.unmodifiable(
        props.showSuggestedItems ? props.suggestedItems : <T>[]);
  }

  bool _isDisabled(T item) =>
      widget.popupProps.disabledItemFn?.call(item) == true;
  bool _isSelectedItem(T item) =>
      getSelectedItems.any((value) => _isEqual(value, item));

  Future<void> _refreshSmartItems() async {
    if (!mounted) return;
    final query = ++_smartQueryRevision;
    final sourceRevision = _source.revision;
    final props = widget.smartSelectionProps;
    if (props == null) {
      _smartPresentation.value = SmartSelectionPresentation<T>(items: []);
      return;
    }
    final canonical = <String, T>{};
    var canPrune = _source.complete;
    for (final item in _source.items) {
      try {
        canonical[props.itemToString(item)] = item;
      } catch (_) {
        canPrune = false;
      }
    }
    final cacheRevision = DropdownCacheStorage.smartRevision(props.tag);
    bool current() =>
        mounted &&
        query == _smartQueryRevision &&
        sourceRevision == _source.revision &&
        identical(widget.smartSelectionProps, props) &&
        cacheRevision == DropdownCacheStorage.smartRevision(props.tag);
    try {
      final ranked = await SmartSelectionDatabase().ranked(
          tag: props.tag,
          usageRange: props.usageRange,
          isCurrent: current,
          validItems: canPrune ? canonical.keys.toSet() : null);
      if (!current()) return;
      final eligible = <SmartSelectionUsage>[];
      final restored = <String, T>{};
      var highestUnverifiedCount = 0;
      for (final usage in ranked) {
        if (!canonical.containsKey(usage.id)) {
          if (usage.count > highestUnverifiedCount) {
            highestUnverifiedCount = usage.count;
          }
          continue;
        }
        final item = canonical[usage.id] as T;
        try {
          if (!_isEqual(props.itemFromString(usage.id), item) ||
              _isDisabled(item)) {
            continue;
          }
          eligible.add(usage);
          restored[usage.id] = item;
        } catch (_) {
          // A failed restoration cannot supply an actionable item.
        }
      }
      _smartPresentation.value = SmartSelectionPresentation<T>(
          items:
              eligible.take(3).map((usage) => restored[usage.id] as T).toList(),
          builder: props.listBuilder);
      if (!props.autoSelect ||
          _smartAutoAttempted ||
          _smartSelectionRevision != 0 ||
          getSelectedItems.isNotEmpty ||
          !_source.hasData ||
          _startupSmartCacheRevision != cacheRevision) {
        return;
      }
      if (eligible.isEmpty) {
        if (canPrune) _smartAutoAttempted = true;
        return;
      }
      final leader = eligible.first;
      // A partial page cannot disqualify a higher-ranked, unseen item.
      if (highestUnverifiedCount >= leader.count) return;
      _smartAutoAttempted = true;
      if (eligible.length > 1 && eligible[1].count == leader.count) return;
      final item = restored[leader.id] as T;
      final revision = _smartSelectionRevision;
      final historyRevision = _smartHistoryRevision;
      final beforeChange = widget.onBeforeChange;
      if (beforeChange != null &&
          await beforeChange(getSelectedItem, item) != true) {
        return;
      }
      if (mounted &&
          identical(widget.smartSelectionProps, props) &&
          historyRevision == _smartHistoryRevision &&
          cacheRevision == DropdownCacheStorage.smartRevision(props.tag) &&
          revision == _smartSelectionRevision &&
          getSelectedItems.isEmpty &&
          widget.smartSelectionProps?.autoSelect == true &&
          _source.items.any((value) =>
              _isEqual(value, item) &&
              props.itemToString(value) == leader.id)) {
        _commitSelectedItems([item]);
      }
    } catch (_) {
      if (current()) {
        _smartPresentation.value = SmartSelectionPresentation<T>(
            items: [], builder: props.listBuilder);
      }
    }
  }

  void _recordSmartSelectionTap(T item) {
    _smartSelectionRevision++;
    final props = widget.smartSelectionProps;
    if (props == null ||
        !widget.enabled ||
        widget.popupProps.disabledItemFn?.call(item) == true) {
      return;
    }
    try {
      SmartSelectionDatabase()
          .recordClick(
            tag: props.tag,
            item: props.itemToString(item),
          )
          .catchError((Object _, StackTrace __) {});
    } catch (_) {
      // A transformer or unavailable store must not prevent the user's tap.
    }
  }

  @override
  void didUpdateWidget(DropdownSearch<T> oldWidget) {
    if (!identical(oldWidget.smartSelectionProps, widget.smartSelectionProps) ||
        !listEquals(oldWidget.selectedItems, widget.selectedItems)) {
      _smartSelectionRevision++;
    }
    _validateItemsLoadMode();
    _updateSuggestedItems();
    if (oldWidget.itemsLoadMode != widget.itemsLoadMode) {
      _smartSelectionRevision++;
      _lastSourceLoaderRevision = -1;
      _source.reset();
      _itemsLoader.reset(widget.itemsLoadMode);
    }
    if (!listEquals(oldWidget.selectedItems, widget.selectedItems)) {
      _selectedItemsNotifier.value = List.from(widget.selectedItems);
    }

    if (!identical(oldWidget.smartSelectionProps, widget.smartSelectionProps) ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.popupProps.disabledItemFn !=
            widget.popupProps.disabledItemFn) {
      Future.microtask(() {
        if (mounted) {
          _refreshSmartItems();
        }
      });
    }

    ///this code check if we need to refresh the popup widget to update
    ///containerBuilder widget
    if (widget.popupProps.containerBuilder !=
        oldWidget.popupProps.containerBuilder) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        _popupStateKey.currentState?.setState(() {});
      });
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<T>>(
      valueListenable: _selectedItemsNotifier,
      builder: (context, data, wt) {
        return IgnorePointer(
          ignoring: !widget.enabled,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomInkWell(
                clickProps: widget.clickProps,
                onTap: () => _selectSearchMode(),
                child: _dropDown(),
              ),
              ValueListenableBuilder<List<T>>(
                  valueListenable: _suggestedItems,
                  builder: (context, items, _) => _buildSuggestedItems(items)),
            ],
          ),
        );
      },
    );
  }

  void _handleFieldSuggestedTap(T item) {
    if (!widget.enabled || _isDisabled(item)) return;
    _recordSmartSelectionTap(item);
    if (!widget.isMultiSelectionMode) {
      _handleOnChangeSelectedItems([item]);
    } else {
      final next = List<T>.of(getSelectedItems);
      if (_isSelectedItem(item)) {
        next.removeWhere((value) => _isEqual(value, item));
      } else {
        next.add(item);
      }
      _handleOnChangeSelectedItems(next);
    }
  }

  Widget _buildSuggestedItems(List<T> suggestedItems) {
    if (suggestedItems.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(builder: (context, constraints) {
        return CustomSingleScrollView(
          scrollProps: widget.popupProps.suggestedItemProps.scrollProps,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment:
                  widget.popupProps.suggestedItemProps.suggestedItemsAlignment,
              children: suggestedItems
                  .map(
                    (f) => CustomInkWell(
                      clickProps:
                          widget.popupProps.suggestedItemProps.itemClickProps,
                      onTap: _isDisabled(f)
                          ? null
                          : () => _handleFieldSuggestedTap(f),
                      child: widget.popupProps.suggestedItemProps
                                  .suggestedItemBuilder !=
                              null
                          ? widget.popupProps.suggestedItemProps
                                  .suggestedItemBuilder!(
                              context, f, _isSelectedItem(f))
                          : _suggestedItemDefaultWidget(f),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      }),
    );
  }

  Widget _suggestedItemDefaultWidget(T item) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).primaryColorLight),
      child: Row(
        children: [
          Text(
            _itemAsString(item),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Padding(padding: EdgeInsets.only(left: 8)),
          Visibility(
            child: Icon(Icons.check_box_outlined),
            visible: _isSelectedItem(item),
          )
        ],
      ),
    );
  }

  Widget _dropDown() {
    if (widget.mode == Mode.custom) {
      return _customField();
    } else {
      return _formField();
    }
  }

  Widget _defaultSelectedItemWidget() {
    Widget defaultItemMultiSelectionMode(T item) {
      return Container(
        padding: EdgeInsets.only(left: 8, right: 1),
        margin: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).primaryColorLight,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _itemAsString(item),
              style: Theme.of(context).textTheme.titleSmall,
              overflow: TextOverflow.ellipsis,
            ),
            Padding(padding: EdgeInsets.only(left: 8)),
            SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                iconSize: 20,
                padding: EdgeInsets.zero,
                icon: Icon(Icons.close_outlined, size: 20),
                onPressed: () => removeItem(item),
              ),
            )
          ],
        ),
      );
    }

    Widget selectedItemWidget() {
      if (widget.dropdownBuilder != null) {
        return widget.dropdownBuilder!(context, getSelectedItem);
      } else if (widget.dropdownBuilderMultiSelection != null) {
        return widget.dropdownBuilderMultiSelection!(context, getSelectedItems);
      } else if (isMultiSelectionMode) {
        return CustomSingleScrollView(
          scrollProps: widget.selectedItemsScrollProps ?? ScrollProps(),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: getSelectedItems
                .map((e) => defaultItemMultiSelectionMode(e))
                .toList(),
          ),
        );
      }
      return Text(
        _itemAsString(getSelectedItem),
        style: _getBaseTextStyle(),
        textAlign: widget.decoratorProps.textAlign,
      );
    }

    return selectedItemWidget();
  }

  TextStyle? _getBaseTextStyle() {
    return widget.enabled
        ? widget.decoratorProps.baseStyle
        : TextStyle(color: Theme.of(context).disabledColor)
            .merge(widget.decoratorProps.baseStyle);
  }

  Widget _formField() {
    return isMultiSelectionMode
        ? _formFieldMultiSelection()
        : _formFieldSingleSelection();
  }

  Widget _customField() => _defaultSelectedItemWidget();

  Widget _formFieldSingleSelection() {
    return FormField<T>(
      enabled: widget.enabled,
      onSaved: widget.onSaved,
      validator: widget.validator,
      autovalidateMode: widget.autoValidateMode,
      initialValue: getSelectedItem,
      builder: (FormFieldState<T> state) {
        if (state.value != getSelectedItem) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              state.didChange(getSelectedItem);
            }
          });
        }
        return ValueListenableBuilder<bool>(
            valueListenable: _isFocused,
            builder: (context, isFocused, w) {
              return InputDecorator(
                baseStyle: _getBaseTextStyle(),
                textAlign: widget.decoratorProps.textAlign,
                textAlignVertical: widget.decoratorProps.textAlignVertical,
                isEmpty: getSelectedItem == null,
                isFocused: isFocused,
                expands: widget.decoratorProps.expands,
                isHovering: widget.decoratorProps.isHovering,
                decoration: _manageDropdownDecoration(state),
                child: _defaultSelectedItemWidget(),
              );
            });
      },
    );
  }

  Widget _formFieldMultiSelection() {
    return FormField<List<T>>(
      enabled: widget.enabled,
      onSaved: widget.onSavedMultiSelection,
      validator: widget.validatorMultiSelection,
      autovalidateMode: widget.autoValidateMode,
      initialValue: widget.selectedItems,
      builder: (FormFieldState<List<T>> state) {
        if (!listEquals(state.value, getSelectedItems)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              state.didChange(getSelectedItems);
            }
          });
        }
        return ValueListenableBuilder<bool>(
            valueListenable: _isFocused,
            builder: (context, isFocused, w) {
              return InputDecorator(
                baseStyle: _getBaseTextStyle(),
                textAlign: widget.decoratorProps.textAlign,
                textAlignVertical: widget.decoratorProps.textAlignVertical,
                isEmpty: getSelectedItems.isEmpty,
                expands: widget.decoratorProps.expands,
                isHovering: widget.decoratorProps.isHovering,
                isFocused: isFocused,
                decoration: _manageDropdownDecoration(state),
                child: _defaultSelectedItemWidget(),
              );
            });
      },
    );
  }

  ///manage dropdownSearch field decoration
  InputDecoration _manageDropdownDecoration(FormFieldState state) {
    return widget.decoratorProps.decoration
        .applyDefaults(Theme.of(state.context).inputDecorationTheme)
        .copyWith(
          enabled: widget.enabled,
          suffixIcon: _manageSuffixIcons(),
          errorText: state.errorText,
        );
  }

  ///function that return the String value of an object
  String _itemAsString(T? data) {
    if (data == null) {
      return "";
    } else if (widget.itemAsString != null) {
      return widget.itemAsString!(data);
    }

    return data.toString();
  }

  ///function that manage Trailing icons(close, dropDown)
  Widget? _manageSuffixIcons() {
    clearButtonPressed() => clear();
    dropdownButtonPressed() => _selectSearchMode();

    if (!widget.suffixProps.dropdownButtonProps.isVisible &&
        !widget.suffixProps.clearButtonProps.isVisible) {
      return null;
    }

    return Row(
      textDirection: TextDirection.ltr,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        if (widget.suffixProps.clearButtonProps.isVisible &&
            getSelectedItems.isNotEmpty)
          CustomIconButton(
              props: widget.suffixProps.clearButtonProps,
              onPressed: clearButtonPressed),
        if (widget.suffixProps.dropdownButtonProps.isVisible)
          CustomIconButton(
            props: widget.suffixProps.dropdownButtonProps,
            icon: isFocused
                ? widget.suffixProps.dropdownButtonProps.iconOpened
                : widget.suffixProps.dropdownButtonProps.icon,
            onPressed: dropdownButtonPressed,
          ),
      ],
    );
  }

  ///the goal of this function is to return a position of the popup
  ///taking in consideration menu button width and popup constraints
  RelativeRect _position(RenderBox dropdown, RenderBox overlay) {
    var menuMinWidth = widget.popupProps.constraints.minWidth;
    var menuMaxWidth = widget.popupProps.constraints.maxWidth;

    var menuMinHeight = widget.popupProps.constraints.minHeight;
    var menuMaxHeight = widget.popupProps.constraints.maxHeight;

    var menuWidth = dropdown.size.width;
    var menuHeight = 350.0;

    if (menuMinWidth > 0) {
      menuWidth = menuMinWidth;
    }
    if (menuMaxWidth > 0 && menuMaxWidth < menuWidth) {
      menuWidth = menuMaxWidth;
    }
    if (widget.mode == Mode.custom && dropdown.size.width < 64) {
      menuWidth = 180;
    }

    if (menuMinHeight > 0) {
      menuHeight = menuMinHeight;
    }
    if (menuMaxHeight > 0 && menuMaxHeight < menuHeight) {
      menuHeight = menuMaxHeight;
    }

    return getPosition(dropdown, overlay, Size(menuWidth, menuHeight),
        widget.popupProps.menuProps.align);
  }

  ///open dialog
  Future _openSelectDialog() {
    return showGeneralDialog(
      context: context,
      barrierDismissible: widget.popupProps.dialogProps.barrierDismissible,
      barrierLabel: widget.popupProps.dialogProps.barrierLabel,
      transitionDuration: widget.popupProps.dialogProps.transitionDuration,
      barrierColor:
          widget.popupProps.dialogProps.barrierColor ?? Colors.black54,
      useRootNavigator: widget.popupProps.dialogProps.useRootNavigator,
      anchorPoint: widget.popupProps.dialogProps.anchorPoint,
      transitionBuilder: widget.popupProps.dialogProps.transitionBuilder,
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlertDialog(
          buttonPadding: widget.popupProps.dialogProps.buttonPadding,
          actionsOverflowButtonSpacing:
              widget.popupProps.dialogProps.actionsOverflowButtonSpacing,
          insetPadding: widget.popupProps.dialogProps.insetPadding,
          actionsPadding: widget.popupProps.dialogProps.actionsPadding,
          actionsOverflowDirection:
              widget.popupProps.dialogProps.actionsOverflowDirection,
          actionsOverflowAlignment:
              widget.popupProps.dialogProps.actionsOverflowAlignment,
          actionsAlignment: widget.popupProps.dialogProps.actionsAlignment,
          actions: widget.popupProps.dialogProps.actions,
          alignment: widget.popupProps.dialogProps.alignment,
          clipBehavior: widget.popupProps.dialogProps.clipBehavior,
          elevation: widget.popupProps.dialogProps.elevation,
          contentPadding: widget.popupProps.dialogProps.contentPadding,
          shape: widget.popupProps.dialogProps.shape,
          backgroundColor: widget.popupProps.dialogProps.backgroundColor,
          semanticLabel: widget.popupProps.dialogProps.semanticLabel,
          shadowColor: widget.popupProps.dialogProps.shadowColor,
          surfaceTintColor: widget.popupProps.dialogProps.surfaceTintColor,
          content: _popupWidgetInstance(),
        );
      },
    );
  }

  Future _openBottomSheet() {
    return showBottomSheet(
      context: context,
      showDragHandle: widget.popupProps.bottomSheetProps.showDragHandle,
      sheetAnimationStyle:
          widget.popupProps.bottomSheetProps.sheetAnimationStyle,
      enableDrag: widget.popupProps.bottomSheetProps.enableDrag,
      backgroundColor: widget.popupProps.bottomSheetProps.backgroundColor ??
          Theme.of(context).bottomSheetTheme.backgroundColor ??
          Theme.of(context).scaffoldBackgroundColor,
      clipBehavior: widget.popupProps.bottomSheetProps.clipBehavior,
      elevation: widget.popupProps.bottomSheetProps.elevation,
      shape: widget.popupProps.bottomSheetProps.shape,
      transitionAnimationController:
          widget.popupProps.bottomSheetProps.transitionAnimationController,
      constraints: widget.popupProps.bottomSheetProps.constraints,
      builder: (ctx) => _popupWidgetInstance(),
    ).closed;
  }

  ///open BottomSheet (Dialog mode)
  Future _openModalBottomSheet() {
    final sheetTheme = Theme.of(context).bottomSheetTheme;
    return showModalBottomSheet<T>(
        context: context,
        barrierLabel: widget.popupProps.modalBottomSheetProps.barrierLabel,
        scrollControlDisabledMaxHeightRatio: widget.popupProps
            .modalBottomSheetProps.scrollControlDisabledMaxHeightRatio,
        showDragHandle: widget.popupProps.modalBottomSheetProps.showDragHandle,
        sheetAnimationStyle:
            widget.popupProps.modalBottomSheetProps.sheetAnimationStyle,
        useSafeArea: widget.popupProps.modalBottomSheetProps.useSafeArea,
        barrierColor: widget.popupProps.modalBottomSheetProps.barrierColor,
        backgroundColor:
            widget.popupProps.modalBottomSheetProps.backgroundColor ??
                sheetTheme.modalBackgroundColor ??
                sheetTheme.backgroundColor ??
                Theme.of(context).scaffoldBackgroundColor,
        isDismissible:
            widget.popupProps.modalBottomSheetProps.barrierDismissible,
        isScrollControlled:
            widget.popupProps.modalBottomSheetProps.isScrollControlled,
        enableDrag: widget.popupProps.modalBottomSheetProps.enableDrag,
        clipBehavior: widget.popupProps.modalBottomSheetProps.clipBehavior,
        elevation: widget.popupProps.modalBottomSheetProps.elevation,
        shape: widget.popupProps.modalBottomSheetProps.shape,
        anchorPoint: widget.popupProps.modalBottomSheetProps.anchorPoint,
        useRootNavigator:
            widget.popupProps.modalBottomSheetProps.useRootNavigator,
        transitionAnimationController:
            widget.popupProps.modalBottomSheetProps.animation,
        constraints: widget.popupProps.modalBottomSheetProps.constraints,
        builder: (ctx) {
          return Container(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: _popupWidgetInstance(),
          );
        });
  }

  ///openMenu
  Future _openMenu() {
    // Here we get the render object of our physical button, later to get its size & position
    final dropdownObject = context.findRenderObject() as RenderBox;
    final overlayState =
        Overlay.maybeOf(context) ?? Navigator.of(context).overlay;
    if (overlayState == null) {
      throw FlutterError(
        'No Overlay widget found. To show a dropdown menu, there must be an Overlay widget in the widget tree.',
      );
    }
    final RenderBox overlay =
        overlayState.context.findRenderObject() as RenderBox;

    return showCustomMenu<T>(
      menuModeProps: widget.popupProps.menuProps,
      context: context,
      position: (widget.popupProps.menuProps.positionCallback ?? _position)(
          dropdownObject, overlay),
      child: _popupWidgetInstance(),
    );
  }

  Widget _popupWidgetInstance() {
    return ItemsLoaderScope<T>(
      loader: _itemsLoader,
      source: _source,
      smartSelection: _smartPresentation,
      selectedItems: _selectedItemsNotifier,
      suggestedItems: _suggestedItems,
      isEnabled: () => mounted && widget.enabled,
      canSelect: (item) => mounted && widget.enabled && !_isDisabled(item),
      child: DropdownSearchPopup<T>(
        key: _popupStateKey,
        popupProps: widget.popupProps,
        itemAsString: widget.itemAsString,
        filterFn: widget.filterFn,
        items: widget.items == null
            ? null
            : (filter, loadProps) =>
                widget.items?.call(filter, loadProps) ?? <T>[],
        onChanged: _handleOnChangeSelectedItems,
        onItemTapped: _recordSmartSelectionTap,
        compareFn: widget.compareFn,
        isMultiSelectionMode: isMultiSelectionMode,
        defaultSelectedItems: List.from(getSelectedItems),
      ),
    );
  }

  ///Function that manage focus listener
  ///set true only if the widget already not focused to prevent unnecessary build
  ///same thing for clear focus,
  void _handleFocus(bool isFocused) {
    if (isFocused && !_isFocused.value) {
      FocusScope.of(context).unfocus();
      _isFocused.value = true;
    } else if (!isFocused && _isFocused.value) {
      _isFocused.value = false;
    }
  }

  ///handle on change value , if the validation is active , we validate the new selected item
  void _handleOnChangeSelectedItems(List<T> selectedItems) {
    _smartSelectionRevision++;
    changeItem() {
      if (mounted) _commitSelectedItems(selectedItems);
    }

    if (widget.onBeforeChange != null) {
      widget.onBeforeChange!(getSelectedItem,
              selectedItems.isEmpty ? null : selectedItems.first)
          .then((value) {
        if (value == true) {
          changeItem();
        }
      });
    } else if (widget.onBeforeChangeMultiSelection != null) {
      widget.onBeforeChangeMultiSelection!(getSelectedItems, selectedItems)
          .then((value) {
        if (value == true) {
          changeItem();
        }
      });
    } else {
      changeItem();
    }

    _handleFocus(false);
  }

  void _commitSelectedItems(List<T> selectedItems) {
    _selectedItemsNotifier.value = List.from(selectedItems);
    if (widget.onChanged != null) {
      widget.onChanged!(getSelectedItem);
    } else if (widget.onChangedMultiSelection != null) {
      widget.onChangedMultiSelection!(selectedItems);
    }
  }

  ///compared two items base on user params
  bool _isEqual(T i1, T i2) {
    if (widget.compareFn != null) {
      return widget.compareFn!(i1, i2);
    } else {
      return i1 == i2;
    }
  }

  ///Function that return then UI based on searchMode
  ///[data] selected item to be passed to the UI
  ///If we close the popup , or maybe we just selected
  ///another widget we should clear the focus
  Future<void> _selectSearchMode() async {
    //fix Duplicate GlobalKey detected in widget tree.
    //if the popup not yet disposed do nothing => solve issue fast click
    if (_popupStateKey.currentState != null) return;

    //handle onBefore popupOpening
    if (widget.onBeforePopupOpening != null) {
      if (await widget.onBeforePopupOpening!(getSelectedItem) == false) return;
    } else if (widget.onBeforePopupOpeningMultiSelection != null) {
      if (await widget.onBeforePopupOpeningMultiSelection!(getSelectedItems) ==
          false) {
        return;
      }
    }

    _handleFocus(true);
    if (widget.popupProps.mode == PopupMode.menu) {
      await _openMenu();
    } else if (widget.popupProps.mode == PopupMode.modalBottomSheet) {
      await _openModalBottomSheet();
    } else if (widget.popupProps.mode == PopupMode.bottomSheet) {
      await _openBottomSheet();
    } else {
      await _openSelectDialog();
    }

    _handleFocus(false);
  }

  @override
  void dispose() {
    final popup = _popupStateKey.currentState;
    if (popup != null) {
      // The navigator may also be unmounting. Close a surviving popup only
      // after the tree has finished updating, while its context is active.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (popup.mounted) popup.closePopup();
      });
    }
    _smartSubscription?.cancel();
    _itemsLoader.removeListener(_onOwnerItemsLoaded);
    _source.removeListener(_onSourceChanged);
    _source.dispose();
    _smartPresentation.dispose();
    _suggestedItems.dispose();
    _itemsLoader.dispose();
    super.dispose();
  }

  ///Change selected Value; this function is public USED to change the selected
  ///value PROGRAMMATICALLY, Otherwise you can use [_handleOnChangeSelectedItems]
  ///for multiSelection mode you can use [changeSelectedItems]
  void changeSelectedItem(T? selectedItem) =>
      _handleOnChangeSelectedItems(DropdownSearch._itemToList(selectedItem));

  ///Change selected Value; this function is public USED to change the selected
  ///value PROGRAMMATICALLY, Otherwise you can use [_handleOnChangeSelectedItems]
  ///for SingleSelection mode you can use [changeSelectedItem]
  void changeSelectedItems(List<T> selectedItems) =>
      _handleOnChangeSelectedItems(selectedItems);

  ///function to remove an item from the list
  ///Useful in multiSelection mode to delete an item
  void removeItem(T itemToRemove) => _handleOnChangeSelectedItems(
      getSelectedItems..removeWhere((i) => _isEqual(itemToRemove, i)));

  ///Change selected Value; this function is public USED to clear selected
  ///value PROGRAMMATICALLY, Otherwise you can use [_handleOnChangeSelectedItems]
  void clear() => _handleOnChangeSelectedItems([]);

  ///get selected value programmatically USED for SINGLE_SELECTION mode
  T? get getSelectedItem =>
      getSelectedItems.isEmpty ? null : getSelectedItems.first;

  ///get selected values programmatically
  List<T> get getSelectedItems => _selectedItemsNotifier.value;

  ///check if the dropdownSearch is focused
  bool get isFocused => _isFocused.value;

  ///return true if we are in multiSelection mode , false otherwise
  bool get isMultiSelectionMode => widget.isMultiSelectionMode;

  ///Deselect items programmatically on the popup of selection
  void popupDeselectItems(List<T> itemsToDeselect) {
    _popupStateKey.currentState?.deselectItems(itemsToDeselect);
  }

  ///Deselect ALL items programmatically on the popup of selection
  void popupDeselectAllItems() {
    _popupStateKey.currentState?.deselectAllItems();
  }

  ///select ALL items programmatically on the popup of selection
  void popupSelectAllItems() {
    _popupStateKey.currentState?.selectAllItems();
  }

  ///select items programmatically on the popup of selection
  void popupSelectItems(List<T> itemsToSelect) {
    _popupStateKey.currentState?.selectItems(itemsToSelect);
  }

  ///validate selected items programmatically on the popup of selection
  void popupOnValidate() {
    _popupStateKey.currentState?.onValidate();
  }

  ///validate selected items programmatically passed in param [itemsToValidate]
  void popupValidate(List<T> itemsToValidate) {
    closeDropDownSearch();
    changeSelectedItems(itemsToValidate);
  }

  ///Public Function that return then UI based on searchMode
  ///[data] selected item to be passed to the UI
  ///If we close the popup , or maybe we just selected
  ///another widget we should clear the focus
  ///THIS USED FOR OPEN DROPDOWN_SEARCH PROGRAMMATICALLY,
  ///otherwise you can you [_selectSearchMode]
  void openDropDownSearch() => _selectSearchMode();

  /// Opens the dropdown search if no value is selected
  void maybeOpenDropDownSearch() {
    if (getSelectedItem == null) return;
    openDropDownSearch();
  }

  ///return the state of the popup
  DropdownSearchPopupState<T>? get getPopupState => _popupStateKey.currentState;

  ///close dropdownSearch popup if it's open
  void closeDropDownSearch() => _popupStateKey.currentState?.closePopup();

  ///returns true if all popup's items are selected; other wise False
  bool get popupIsAllItemSelected =>
      _popupStateKey.currentState?.isAllItemSelected ?? false;

  ///returns popup selected items
  List<T> get popupGetSelectedItems =>
      _popupStateKey.currentState?.getSelectedItem ?? [];

  ///returns popup showed/loaded items
  List<T> get popupGetItems =>
      _popupStateKey.currentState?.getLoadedItems ?? [];

  ///add a suggested item to the popup
  void popupAddPinnedItem(T item) =>
      _popupStateKey.currentState?.addPinnedItem(item);

  ///remove a suggested item from the popup
  void popupRemovePinnedItem(T item) =>
      _popupStateKey.currentState?.removePinnedItem(item);

  ///returns suggested items
  List<T> get popupGetSuggestedItems => List<T>.of(_suggestedItems.value);

  void updatePopupState() => _popupStateKey.currentState?.setState(() {});

  /// Loads or refreshes items, even when the popup is closed.
  ///
  /// Successful loads replace the internal list and refresh an open popup.
  /// Requests use an empty filter; cached modes request a complete list without
  /// pagination. Concurrent calls share the pending request. Errors propagate
  /// to the caller and do not discard the last successful list.
  /// In [ItemsLoadMode.onOpen], the next opening still loads normally.
  Future<List<T>> loadItems() {
    if (!mounted) {
      return Future.error(StateError('The dropdown has been disposed'));
    }
    _validateItemsLoadMode();
    return _itemsLoader.load();
  }

  /// Retrieves the items programatically
  ///
  /// [autoSelectIfOneItem] if true and [items] is only one item, the item will be selected automatically
  /// [filterDisabledItems] if true and [items] has disabled items, they will be filtered out
  Future<List<T>?> retrieveItems({
    bool autoSelectIfOneItem = false,
    bool filterDisabledItems = false,
    String filter = "",
  }) async {
    var retrieveItems = await widget.items?.call(
      filter,
      widget.popupProps.infiniteScrollProps?.loadProps,
    );

    if (retrieveItems == null) return null;

    final popUpItemProps = widget.popupProps.disabledItemFn;

    if (filterDisabledItems && popUpItemProps != null) {
      retrieveItems =
          retrieveItems.where((item) => !popUpItemProps(item)).toList();
    }

    switch (retrieveItems.length) {
      case 0:
        return null;
      case 1:
        if (autoSelectIfOneItem) {
          _handleOnChangeSelectedItems([retrieveItems.first]);
        }
        return retrieveItems;

      default:
        return retrieveItems;
    }
  }
}
