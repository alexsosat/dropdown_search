import 'dart:async';

import 'package:dropdown_search/src/data/data_sources/pinned_items_database.dart';
import 'package:dropdown_search/src/widgets/custom_inkwell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../dropdown_search.dart';
import '../items_loader.dart';
import '../dropdown_source.dart';
import 'checkbox_widget.dart';

class DropdownSearchPopup<T> extends StatefulWidget {
  final ValueChanged<List<T>>? onChanged;

  /// Reports enabled user item taps, excluding automatic/programmatic changes.
  /// Gestures owned by the caller through interceptCallBacks are not observed.
  final ValueChanged<T>? onItemTapped;
  final DropdownSearchOnFind<T>? items;
  final DropdownSearchItemAsString<T>? itemAsString;
  final DropdownSearchFilterFn<T>? filterFn;
  final DropdownSearchCompareFn<T>? compareFn;
  final List<T> defaultSelectedItems;
  final PopupPropsMultiSelection<T> popupProps;
  final bool isMultiSelectionMode;

  const DropdownSearchPopup({
    super.key,
    required this.popupProps,
    this.defaultSelectedItems = const [],
    this.isMultiSelectionMode = false,
    this.onChanged,
    this.onItemTapped,
    this.items,
    this.itemAsString,
    this.filterFn,
    this.compareFn,
  });

  @override
  DropdownSearchPopupState<T> createState() => DropdownSearchPopupState<T>();
}

class DropdownSearchPopupState<T> extends State<DropdownSearchPopup<T>> {
  final StreamController<List<T>> _itemsStream = StreamController.broadcast();
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier(false);
  final List<T> _cachedItems = [];
  final ValueNotifier<List<T>> _selectedItemsNotifier = ValueNotifier([]);
  final ScrollController scrollController = ScrollController();
  final List<T> _currentShowedItems = [];
  late TextEditingController searchBoxController;
  late bool isInfiniteScrollEnded;
  ItemsLoaderScope<T>? _ownerScope;
  ValueListenable<List<T>>? _ownerSelected;
  List<T> get suggestedItems => _ownerScope?.suggestedItems?.value ?? <T>[];
  final List<T> pinnedItems = [];

  final PinnedItemsDatabase _pinnedItemsDatabase = PinnedItemsDatabase();
  Future<void>? _pinnedItemsLoadFuture;
  ItemsLoader<T>? _itemsLoader;
  ItemsLoadMode? _itemsLoadMode;
  int _sharedRevision = -1;
  String? _sharedFilter;
  Object? _sharedError;
  bool _firstSharedPresentation = true;
  int _loadGeneration = 0;

  List<T> get _selectedItems => _selectedItemsNotifier.value;
  Timer? _debounce;
  String lastSearchText = '';

  void searchBoxControllerListener() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();

    //handle case when editText get focused, onTextChange was called !
    if (lastSearchText == searchBoxController.text) return;

    _debounce = Timer(widget.popupProps.searchDelay, () {
      lastSearchText = searchBoxController.text;
      _manageLoadItems(searchBoxController.text);
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedItemsNotifier.value = widget.defaultSelectedItems;

    searchBoxController = widget.popupProps.searchFieldProps.controller ??
        TextEditingController();
    searchBoxController.addListener(searchBoxControllerListener);

    lastSearchText = searchBoxController.text;

    isInfiniteScrollEnded = widget.popupProps.infiniteScrollProps == null;

    Future.delayed(
      Duration.zero,
      () => _manageLoadItems(searchBoxController.text, isFirstLoad: true),
    );
  }

  Future<void> _loadPinnedItems() async {
    final props = widget.popupProps.pinnedItemsProps;
    if (props == null || !props.showPinnedItems) return;

    await PinnedItemsDatabase.init();
    if (!mounted) return;

    for (final savedItem in _pinnedItemsDatabase.get(props.pinnedItemsTag)) {
      final item = props.pinnedItemsEntityTransformer(savedItem);
      if (!_isDisabled(item) && _itemIndexInList(pinnedItems, item) == -1) {
        pinnedItems.add(item);
      }
    }
  }

  bool _isPinned(T item) =>
      widget.popupProps.pinnedItemsProps?.showPinnedItems == true &&
      !_isDisabled(item) &&
      _itemIndexInList(pinnedItems, item) != -1;

  List<T> _orderPinnedItems(List<T> items) {
    if (widget.popupProps.pinnedItemsProps?.showPinnedItems != true ||
        pinnedItems.isEmpty) {
      return items;
    }

    // Render loaded objects in saved pin order without changing source order.
    final pinnedRows = List.generate(pinnedItems.length, (_) => <T>[]);
    final unpinnedRows = <T>[];
    for (final item in items) {
      final pinIndex =
          _isPinned(item) ? _itemIndexInList(pinnedItems, item) : -1;
      if (pinIndex == -1) {
        unpinnedRows.add(item);
      } else {
        pinnedRows[pinIndex].add(item);
      }
    }
    return [...pinnedRows.expand((rows) => rows), ...unpinnedRows];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ownerScope =
        context.dependOnInheritedWidgetOfExactType<ItemsLoaderScope<T>>();
    final ownerSelected = _ownerScope?.selectedItems;
    if (_ownerSelected != ownerSelected) {
      _ownerSelected?.removeListener(_syncOwnerSelection);
      _ownerSelected = ownerSelected;
      _ownerSelected?.addListener(_syncOwnerSelection);
      _syncOwnerSelection();
    }
    final loader = _ownerScope?.loader;
    if (_itemsLoader != loader) {
      _itemsLoader?.removeListener(_onItemsLoaderChanged);
      _itemsLoader = loader;
      _itemsLoadMode = loader?.mode;
      loader?.addListener(_onItemsLoaderChanged);
    }
  }

  void _syncOwnerSelection() {
    if (mounted && _ownerSelected != null) {
      _selectedItemsNotifier.value = List<T>.of(_ownerSelected!.value);
    }
  }

  void _onItemsLoaderChanged() {
    if (!mounted) return;
    final loader = _itemsLoader!;
    _loadGeneration++;
    if (_itemsLoadMode != loader.mode) {
      _itemsLoadMode = loader.mode;
      _sharedRevision = -1;
      _sharedFilter = null;
      _sharedError = null;
      _firstSharedPresentation = true;
      _cachedItems.clear();
      _debounce?.cancel();
      // The owning dropdown may be in didUpdateWidget when the mode changes.
      Future.delayed(Duration.zero, () {
        if (mounted) {
          _loadingNotifier.value = false;
          _manageLoadItems(searchBoxController.text, isFirstLoad: true);
        }
      });
      return;
    }
    _loadingNotifier.value = loader.isLoading;
    _showSharedItems();
  }

  Future<void> _showSharedItems() async {
    final loader = _itemsLoader;
    if (loader == null || !mounted) return;
    try {
      await (_pinnedItemsLoadFuture ??= _loadPinnedItems());
    } catch (error, stackTrace) {
      _setErrorToStream(error, stackTrace);
      return;
    }
    if (!mounted || loader != _itemsLoader || loader.isLoading) return;
    if (loader.error != null) {
      if (!identical(_sharedError, loader.error)) {
        _sharedError = loader.error;
        _setErrorToStream(loader.error!, loader.stackTrace);
      }
      return;
    }

    final filter = searchBoxController.text;
    if (_sharedRevision == loader.revision && _sharedFilter == filter) return;
    _sharedRevision = loader.revision;
    _sharedFilter = filter;
    _sharedError = null;
    _cachedItems
      ..clear()
      ..addAll(loader.items);
    final loadProps = widget.popupProps.infiniteScrollProps?.loadProps;
    isInfiniteScrollEnded = loader.mode != ItemsLoadMode.onOpen ||
        loadProps == null ||
        loader.items.length < loadProps.take;
    final data =
        loader.mode == ItemsLoadMode.onOpen && widget.popupProps.disableFilter
            ? List<T>.of(_cachedItems)
            : _applyFilter(filter);
    final firstLoad = _firstSharedPresentation;
    _firstSharedPresentation = false;
    _addDataToStream(data, isFirstLoad: firstLoad);
  }

  @override
  void didUpdateWidget(covariant DropdownSearchPopup<T> oldWidget) {
    if (!listEquals(
        oldWidget.defaultSelectedItems, widget.defaultSelectedItems)) {
      _selectedItemsNotifier.value = widget.defaultSelectedItems;
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _itemsLoader?.removeListener(_onItemsLoaderChanged);
    _ownerSelected?.removeListener(_syncOwnerSelection);
    _itemsStream.close();
    _debounce?.cancel();

    if (widget.popupProps.searchFieldProps.controller == null) {
      searchBoxController.dispose();
    } else {
      searchBoxController.removeListener(searchBoxControllerListener);
    }

    if (widget.popupProps.listViewProps.controller == null) {
      scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: widget.popupProps.constraints,
      child: widget.popupProps.containerBuilder == null
          ? _defaultWidget()
          : widget.popupProps.containerBuilder!(context, _defaultWidget()),
    );
  }

  Widget _defaultWidget() {
    return Material(
      type: MaterialType.transparency,
      child: ValueListenableBuilder(
          valueListenable: _selectedItemsNotifier,
          builder: (ctx, value, w) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _searchField(),
                _smartItemsWidget(),
                Flexible(
                  fit: widget.popupProps.fit,
                  child: Stack(
                    children: <Widget>[
                      StreamBuilder<List<T>>(
                        stream: _itemsStream.stream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _errorWidget(snapshot.error);
                          } else if (!snapshot.hasData) {
                            return _loadingWidget();
                          } else if (snapshot.data!.isEmpty) {
                            return _noDataWidget();
                          }

                          final displayedItems =
                              _orderPinnedItems(snapshot.data!);
                          final itemCount = displayedItems.length;
                          return RawScrollbar(
                            controller:
                                widget.popupProps.listViewProps.controller ??
                                    scrollController,
                            thumbVisibility: widget
                                .popupProps.scrollbarProps.thumbVisibility,
                            trackVisibility: widget
                                .popupProps.scrollbarProps.trackVisibility,
                            thickness:
                                widget.popupProps.scrollbarProps.thickness,
                            radius: widget.popupProps.scrollbarProps.radius,
                            notificationPredicate: widget.popupProps
                                .scrollbarProps.notificationPredicate,
                            interactive:
                                widget.popupProps.scrollbarProps.interactive,
                            scrollbarOrientation: widget
                                .popupProps.scrollbarProps.scrollbarOrientation,
                            thumbColor:
                                widget.popupProps.scrollbarProps.thumbColor,
                            fadeDuration:
                                widget.popupProps.scrollbarProps.fadeDuration,
                            crossAxisMargin: widget
                                .popupProps.scrollbarProps.crossAxisMargin,
                            mainAxisMargin:
                                widget.popupProps.scrollbarProps.mainAxisMargin,
                            minOverscrollLength: widget
                                .popupProps.scrollbarProps.minOverscrollLength,
                            minThumbLength:
                                widget.popupProps.scrollbarProps.minThumbLength,
                            pressDuration:
                                widget.popupProps.scrollbarProps.pressDuration,
                            shape: widget.popupProps.scrollbarProps.shape,
                            timeToFade:
                                widget.popupProps.scrollbarProps.timeToFade,
                            trackBorderColor: widget
                                .popupProps.scrollbarProps.trackBorderColor,
                            trackColor:
                                widget.popupProps.scrollbarProps.trackColor,
                            trackRadius:
                                widget.popupProps.scrollbarProps.trackRadius,
                            padding: widget.popupProps.scrollbarProps.padding,
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context)
                                  .copyWith(scrollbars: false),
                              child: ListView.builder(
                                hitTestBehavior: widget
                                    .popupProps.listViewProps.hitTestBehavior,
                                controller: widget
                                        .popupProps.listViewProps.controller ??
                                    scrollController,
                                shrinkWrap:
                                    widget.popupProps.listViewProps.shrinkWrap,
                                padding:
                                    widget.popupProps.listViewProps.padding,
                                scrollDirection: widget
                                    .popupProps.listViewProps.scrollDirection,
                                reverse:
                                    widget.popupProps.listViewProps.reverse,
                                primary:
                                    widget.popupProps.listViewProps.primary,
                                physics:
                                    widget.popupProps.listViewProps.physics,
                                itemExtent:
                                    widget.popupProps.listViewProps.itemExtent,
                                addAutomaticKeepAlives: widget.popupProps
                                    .listViewProps.addAutomaticKeepAlives,
                                addRepaintBoundaries: widget.popupProps
                                    .listViewProps.addRepaintBoundaries,
                                addSemanticIndexes: widget.popupProps
                                    .listViewProps.addSemanticIndexes,
                                cacheExtent:
                                    widget.popupProps.listViewProps.cacheExtent,
                                semanticChildCount: widget.popupProps
                                    .listViewProps.semanticChildCount,
                                dragStartBehavior: widget
                                    .popupProps.listViewProps.dragStartBehavior,
                                keyboardDismissBehavior: widget.popupProps
                                    .listViewProps.keyboardDismissBehavior,
                                restorationId: widget
                                    .popupProps.listViewProps.restorationId,
                                clipBehavior: widget
                                    .popupProps.listViewProps.clipBehavior,
                                prototypeItem: widget
                                    .popupProps.listViewProps.prototypeItem,
                                itemExtentBuilder: widget
                                    .popupProps.listViewProps.itemExtentBuilder,
                                findChildIndexCallback: widget.popupProps
                                    .listViewProps.findChildIndexCallback,
                                itemCount:
                                    itemCount + (isInfiniteScrollEnded ? 0 : 1),
                                itemBuilder: (context, index) {
                                  if (index < itemCount) {
                                    var item = displayedItems[index];
                                    return widget.isMultiSelectionMode
                                        ? _itemWidgetMultiSelection(item)
                                        : _itemWidgetSingleSelection(item);
                                  }
                                  //if infiniteScroll enabled && data received not less then take request
                                  else if (!isInfiniteScrollEnded) {
                                    _manageLoadMoreItems(
                                        searchBoxController.text,
                                        skip: itemCount,
                                        showLoading: false);
                                    return _infiniteScrollLoadingMoreWidget(
                                        itemCount);
                                  }

                                  return SizedBox.shrink();
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      _loadingWidget()
                    ],
                  ),
                ),
                _multiSelectionValidation(),
              ],
            );
          }),
    );
  }

  Widget _infiniteScrollLoadingMoreWidget(int loadedItems) {
    if (widget.popupProps.infiniteScrollProps?.loadingMoreBuilder != null) {
      return widget.popupProps.infiniteScrollProps!.loadingMoreBuilder!(
          context, loadedItems);
    }
    return const Center(child: CircularProgressIndicator());
  }

  ///validation of selected items
  void onValidate() {
    closePopup();
    if (widget.onChanged != null) widget.onChanged!(_selectedItems);
  }

  Widget _multiSelectionValidation() {
    if (!widget.isMultiSelectionMode) return SizedBox.shrink();

    Widget defaultValidation = Padding(
      padding: EdgeInsets.all(8),
      child: Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton(
          onPressed: onValidate,
          child: Text("OK"),
        ),
      ),
    );

    if (widget.popupProps.validationBuilder != null) {
      return widget.popupProps.validationBuilder!(context, _selectedItems);
    }

    return defaultValidation;
  }

  Widget _noDataWidget() {
    if (widget.popupProps.emptyBuilder != null) {
      return widget.popupProps.emptyBuilder!(context, searchBoxController.text);
    }

    return Container(
      height: 70,
      alignment: Alignment.center,
      child: Text("No data found"),
    );
  }

  Widget _errorWidget(dynamic error) {
    if (widget.popupProps.errorBuilder != null) {
      return widget.popupProps.errorBuilder!(
        context,
        searchBoxController.text,
        error,
      );
    }

    return Container(
      alignment: Alignment.center,
      child: Text(
        error?.toString() ?? 'Unknown Error',
      ),
    );
  }

  Widget _loadingWidget() {
    return ValueListenableBuilder(
        valueListenable: _loadingNotifier,
        builder: (context, bool isLoading, wid) {
          if (isLoading) {
            if (widget.popupProps.loadingBuilder != null) {
              return widget.popupProps.loadingBuilder!(
                context,
                searchBoxController.text,
              );
            }

            return Container(
              height: 70,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            );
          }
          return const SizedBox.shrink();
        });
  }

  List<T> _applyFilter(String filter) {
    return _cachedItems.where((i) {
      if (widget.filterFn != null) {
        return (widget.filterFn!(i, filter));
      } else if (i.toString().toLowerCase().contains(filter.toLowerCase())) {
        return true;
      } else if (widget.itemAsString != null) {
        return (widget.itemAsString!(i))
            .toLowerCase()
            .contains(filter.toLowerCase());
      }
      return false;
    }).toList();
  }

  Future<void> _manageLoadItems(
    String filter, {
    bool isFirstLoad = false,
  }) async {
    if (!mounted) return;
    final loader = _itemsLoader;
    if (loader != null && loader.mode != ItemsLoadMode.onOpen) {
      final generation = loader.generation;
      _loadingNotifier.value = loader.isLoading;
      if (isFirstLoad &&
          loader.mode == ItemsLoadMode.onFirstOpen &&
          !loader.hasLoaded) {
        try {
          await loader.load();
        } catch (_) {
          // The shared loading state publishes the error to the popup.
        }
      }
      if (loader.generation != generation) return;
      await _showSharedItems();
      return;
    }
    final generation = ++_loadGeneration;
    try {
      await (_pinnedItemsLoadFuture ??= _loadPinnedItems());
    } catch (error, stackTrace) {
      _setErrorToStream(error, stackTrace);
      return;
    }
    if (!mounted || generation != _loadGeneration) return;

    //if the filter is not handled by user, we load full list once
    if (!widget.popupProps.cacheItems) _cachedItems.clear();

    //case filtering locally (no need to load new data)
    if (!isFirstLoad &&
        !widget.popupProps.disableFilter &&
        widget.popupProps.cacheItems &&
        isInfiniteScrollEnded) {
      _addDataToStream(_applyFilter(filter), isFirstLoad: isFirstLoad);
      return;
    }

    return _manageLoadMoreItems(filter, isFirstLoad: isFirstLoad);
  }

  Future<void> _manageLoadMoreItems(
    String filter, {
    int? skip,
    bool showLoading = true,
    bool isFirstLoad = false,
  }) async {
    if (!mounted || widget.items == null) return;
    final generation = _loadGeneration;

    final loadProps = widget.popupProps.infiniteScrollProps?.loadProps;

    if (showLoading) {
      _loadingNotifier.value = true;
    }

    try {
      final List<T> myItems =
          await widget.items!(filter, loadProps?.copy(skip: skip));
      if (!mounted || generation != _loadGeneration) return;

      if (loadProps != null) {
        isInfiniteScrollEnded = myItems.length < loadProps.take;
      }

      //add new online items to cache list
      _cachedItems.addAll(myItems);
      final source = _ownerScope?.source;
      if (filter.isEmpty && source != null) {
        final offset = skip ?? loadProps?.skip ?? 0;
        final prefix = offset == 0 ||
            (source.hasData &&
                source.completePrefix &&
                offset == source.items.length);
        source.publish(
            skip == null || skip == 0 ? myItems : [...source.items, ...myItems],
            completePrefix: prefix,
            complete: prefix && isInfiniteScrollEnded);
      }

      //manage data filtering
      if (widget.popupProps.disableFilter) {
        _addDataToStream(_cachedItems, isFirstLoad: isFirstLoad);
      } else {
        _addDataToStream(_applyFilter(filter), isFirstLoad: isFirstLoad);
      }
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      _setErrorToStream(e);
    }

    if (mounted && showLoading) {
      _loadingNotifier.value = false;
    }
  }

  void _addDataToStream(List<T> data, {bool isFirstLoad = false}) {
    if (_itemsStream.isClosed) return;
    _itemsStream.add(data);

    //update showed data list
    _currentShowedItems.clear();
    _currentShowedItems.addAll(data);

    if (widget.popupProps.onItemsLoaded != null) {
      widget.popupProps.onItemsLoaded!(data);
    }

    // TODO: Add a snackbar to show that the item was auto-selected
    if ((isFirstLoad ||
            widget.popupProps.itemClickProps.autoSelectIfOnlyOneOnSearch) &&
        widget.popupProps.itemClickProps.autoSelectIfOnlyOne &&
        data.length == 1) {
      if (!_isDisabled(data.first) &&
          !_isSelectedItem(data.first) &&
          !widget.isMultiSelectionMode) {
        _handleSelectedItem(data.first);
      }
    }
  }

  void _setErrorToStream(Object error, [StackTrace? stackTrace]) {
    if (_itemsStream.isClosed) return;
    _itemsStream.addError(error, stackTrace);
  }

  Widget _itemWidgetSingleSelection(T item) {
    if (widget.popupProps.itemBuilder != null) {
      var w = widget.popupProps.itemBuilder!(
        context,
        item,
        _isDisabled(item),
        !widget.popupProps.showSelectedItems ? false : _isSelectedItem(item),
        _isPinned(item),
      );

      if (widget.popupProps.interceptCallBacks) return w;

      return CustomInkWell(
        clickProps: widget.popupProps.itemClickProps,
        onTap: _isDisabled(item) ? null : () => _handleItemTap(item),
        child: IgnorePointer(
          ignoring: widget.popupProps.itemClickProps.ignorePointers,
          child: w,
        ),
      );
    } else {
      return ListTile(
        enabled: !_isDisabled(item),
        title: widget.popupProps.itemProps?.title != null
            ? widget.popupProps.itemProps!.title(item)
            : Text(_selectedItemAsString(item)),
        subtitle: widget.popupProps.itemProps?.subtitle != null
            ? widget.popupProps.itemProps!.subtitle!(item)
            : null,
        leading: widget.popupProps.itemProps?.leading != null
            ? widget.popupProps.itemProps!.leading!(item)
            : null,
        trailing: widget.popupProps.pinnedItemsProps?.showPinnedItems == true
            ? _isSelectedItem(item)
                ? IconButton(
                    onPressed: null,
                    icon: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                  )
                : _buildPinnedItemTrailing(item)
            : null,
        selected: !widget.popupProps.showSelectedItems
            ? false
            : _isSelectedItem(item),
        onTap: _isDisabled(item) ? null : () => _handleItemTap(item),
      );
    }
  }

  Widget _itemWidgetMultiSelection(T item) {
    if (widget.popupProps.checkBoxBuilder != null) {
      return CheckBoxWidget(
        clickProps: widget.popupProps.itemClickProps,
        checkBox: (cxt, checked) {
          return widget.popupProps.checkBoxBuilder!(cxt, item,
              _isDisabled(item), checked, suggestedItems.contains(item));
        },
        interceptCallBacks: widget.popupProps.interceptCallBacks,
        textDirection: widget.popupProps.textDirection,
        layout: (context, isChecked) => _itemWidgetSingleSelection(item),
        isChecked: _isSelectedItem(item),
        isDisabled: _isDisabled(item),
        onChanged: (c) => _handleItemTap(item),
      );
    } else {
      return CheckBoxWidget(
        clickProps: widget.popupProps.itemClickProps,
        textDirection: widget.popupProps.textDirection,
        interceptCallBacks: widget.popupProps.interceptCallBacks,
        layout: (context, isChecked) => _itemWidgetSingleSelection(item),
        isChecked: _isSelectedItem(item),
        isDisabled: _isDisabled(item),
        onChanged: (c) => _handleItemTap(item),
      );
    }
  }

  bool _isDisabled(T item) =>
      widget.popupProps.disabledItemFn != null &&
      (widget.popupProps.disabledItemFn!(item)) == true;

  /// selected item will be highlighted only when [widget.showSelectedItems] is true,
  /// if our object is String [widget.compareFn] is not required , other wises it's required
  bool _isSelectedItem(T item) => _itemIndexInList(_selectedItems, item) > -1;

  ///test if list has an item T
  ///if contains return index of item in the list, -1 otherwise
  int _itemIndexInList(List<T> list, T item) =>
      list.indexWhere((i) => _isEqual(i, item));

  ///compared two items base on user params
  bool _isEqual(T i1, T i2) {
    if (widget.compareFn != null) {
      return widget.compareFn!(i1, i2);
    } else {
      return i1 == i2;
    }
  }

  Widget _searchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        widget.popupProps.title ?? const SizedBox.shrink(),
        if (widget.popupProps.showSearchBox)
          Padding(
            padding: widget.popupProps.searchFieldProps.padding,
            child: Semantics(
              textField: true,
              child: TextField(
                onChanged: widget.popupProps.searchFieldProps.onChanged,
                onEditingComplete:
                    widget.popupProps.searchFieldProps.onEditingComplete,
                onSubmitted: widget.popupProps.searchFieldProps.onSubmitted,
                onTapAlwaysCalled:
                    widget.popupProps.searchFieldProps.onTapAlwaysCalled,
                enableIMEPersonalizedLearning: widget
                    .popupProps.searchFieldProps.enableIMEPersonalizedLearning,
                clipBehavior: widget.popupProps.searchFieldProps.clipBehavior,
                style: widget.popupProps.searchFieldProps.style,
                controller: searchBoxController,
                focusNode: widget.popupProps.searchFieldProps.focusNode,
                autofocus: widget.popupProps.searchFieldProps.autofocus,
                decoration: widget.popupProps.searchFieldProps.decoration,
                keyboardType: widget.popupProps.searchFieldProps.keyboardType,
                textInputAction:
                    widget.popupProps.searchFieldProps.textInputAction,
                textCapitalization:
                    widget.popupProps.searchFieldProps.textCapitalization,
                strutStyle: widget.popupProps.searchFieldProps.strutStyle,
                textAlign: widget.popupProps.searchFieldProps.textAlign,
                textAlignVertical:
                    widget.popupProps.searchFieldProps.textAlignVertical,
                textDirection: widget.popupProps.searchFieldProps.textDirection,
                readOnly: widget.popupProps.searchFieldProps.readOnly,
                contextMenuBuilder:
                    widget.popupProps.searchFieldProps.contextMenuBuilder,
                showCursor: widget.popupProps.searchFieldProps.showCursor,
                obscuringCharacter:
                    widget.popupProps.searchFieldProps.obscuringCharacter,
                obscureText: widget.popupProps.searchFieldProps.obscureText,
                autocorrect: widget.popupProps.searchFieldProps.autocorrect,
                smartDashesType:
                    widget.popupProps.searchFieldProps.smartDashesType,
                smartQuotesType:
                    widget.popupProps.searchFieldProps.smartQuotesType,
                enableSuggestions:
                    widget.popupProps.searchFieldProps.enableSuggestions,
                maxLines: widget.popupProps.searchFieldProps.maxLines,
                minLines: widget.popupProps.searchFieldProps.minLines,
                expands: widget.popupProps.searchFieldProps.expands,
                maxLengthEnforcement:
                    widget.popupProps.searchFieldProps.maxLengthEnforcement,
                maxLength: widget.popupProps.searchFieldProps.maxLength,
                onAppPrivateCommand:
                    widget.popupProps.searchFieldProps.onAppPrivateCommand,
                inputFormatters:
                    widget.popupProps.searchFieldProps.inputFormatters,
                enabled: widget.popupProps.searchFieldProps.enabled,
                cursorWidth: widget.popupProps.searchFieldProps.cursorWidth,
                cursorHeight: widget.popupProps.searchFieldProps.cursorHeight,
                cursorRadius: widget.popupProps.searchFieldProps.cursorRadius,
                cursorColor: widget.popupProps.searchFieldProps.cursorColor,
                selectionHeightStyle:
                    widget.popupProps.searchFieldProps.selectionHeightStyle,
                selectionWidthStyle:
                    widget.popupProps.searchFieldProps.selectionWidthStyle,
                keyboardAppearance:
                    widget.popupProps.searchFieldProps.keyboardAppearance,
                scrollPadding: widget.popupProps.searchFieldProps.scrollPadding,
                dragStartBehavior:
                    widget.popupProps.searchFieldProps.dragStartBehavior,
                enableInteractiveSelection: widget
                    .popupProps.searchFieldProps.enableInteractiveSelection,
                selectionControls:
                    widget.popupProps.searchFieldProps.selectionControls,
                onTap: widget.popupProps.searchFieldProps.onTap,
                mouseCursor: widget.popupProps.searchFieldProps.mouseCursor,
                buildCounter: widget.popupProps.searchFieldProps.buildCounter,
                scrollController:
                    widget.popupProps.searchFieldProps.scrollController,
                scrollPhysics: widget.popupProps.searchFieldProps.scrollPhysics,
                autofillHints: widget.popupProps.searchFieldProps.autofillHints,
                restorationId: widget.popupProps.searchFieldProps.restorationId,
                canRequestFocus:
                    widget.popupProps.searchFieldProps.canRequestFocus,
                statesController:
                    widget.popupProps.searchFieldProps.statesController,
                contentInsertionConfiguration: widget
                    .popupProps.searchFieldProps.contentInsertionConfiguration,
                cursorErrorColor:
                    widget.popupProps.searchFieldProps.cursorErrorColor,
                cursorOpacityAnimates:
                    widget.popupProps.searchFieldProps.cursorOpacityAnimates,
                ignorePointers:
                    widget.popupProps.searchFieldProps.ignorePointers,
                magnifierConfiguration:
                    widget.popupProps.searchFieldProps.magnifierConfiguration,
                onTapOutside: widget.popupProps.searchFieldProps.onTapOutside,
                stylusHandwritingEnabled:
                    widget.popupProps.searchFieldProps.scribbleEnabled,
                undoController:
                    widget.popupProps.searchFieldProps.undoController,
                spellCheckConfiguration:
                    widget.popupProps.searchFieldProps.spellCheckConfiguration,
              ),
            ),
          )
      ],
    );
  }

  Widget _smartItemsWidget() {
    final presentation = _ownerScope?.smartSelection;
    if (presentation == null) return const SizedBox.shrink();
    return ValueListenableBuilder<SmartSelectionPresentation<T>>(
        valueListenable: presentation,
        builder: (context, value, _) {
          final builder = value.builder;
          if (builder == null) return const SizedBox.shrink();
          return IgnorePointer(
              ignoring: _ownerScope?.isEnabled?.call() == false,
              child: builder(context, value.items, _handleSmartItemTap));
        });
  }

  void _handleSmartItemTap(T item) {
    final source = _ownerScope?.source;
    if (source == null) return;
    final index = _itemIndexInList(source.items, item);
    if (index == -1) return;
    final canonical = source.items[index];
    final allowed =
        _ownerScope?.canSelect?.call(canonical) ?? !_isDisabled(canonical);
    if (!allowed) return;
    widget.onItemTapped?.call(canonical);
    _handleSelectedItem(canonical);
  }

  void _handleItemTap(T item) {
    if (_ownerScope?.isEnabled?.call() == false ||
        _ownerScope?.canSelect?.call(item) == false ||
        _isDisabled(item)) {
      return;
    }
    widget.onItemTapped?.call(item);
    _handleSelectedItem(item);
  }

  void _handleSelectedItem(T newSelectedItem) {
    if (widget.isMultiSelectionMode) {
      if (_isSelectedItem(newSelectedItem)) {
        _selectedItemsNotifier.value = List.from(_selectedItems)
          ..removeWhere((i) => _isEqual(newSelectedItem, i));
        if (widget.popupProps.onItemRemoved != null) {
          widget.popupProps.onItemRemoved!(_selectedItems, newSelectedItem);
        }
      } else {
        _selectedItemsNotifier.value = List.from(_selectedItems)
          ..add(newSelectedItem);
        if (widget.popupProps.onItemAdded != null) {
          widget.popupProps.onItemAdded!(_selectedItems, newSelectedItem);
        }
      }
    } else {
      closePopup();
      if (widget.onChanged != null) {
        widget.onChanged!(List.filled(1, newSelectedItem));
      }
    }
  }

  ///function that return the String value of an object
  String _selectedItemAsString(T data) {
    if (data == null) {
      return "";
    } else if (widget.itemAsString != null) {
      return widget.itemAsString!(data);
    } else {
      return data.toString();
    }
  }

  void selectItems(List<T> itemsToSelect) {
    for (var i in itemsToSelect) {
      if (!_isSelectedItem(i) /*check if the item is already selected*/ &&
          !_isDisabled(i) /*escape disabled items*/) {
        _selectedItems.add(i);
        if (widget.popupProps.onItemAdded != null) {
          widget.popupProps.onItemAdded!(_selectedItems, i);
        }
      }
    }
    _selectedItemsNotifier.value = List.from(_selectedItems);
  }

  void deselectItems(List<T> itemsToDeselect) {
    List<T> tempList = List.from(itemsToDeselect);
    for (var i in tempList) {
      var index = _itemIndexInList(_selectedItems, i);
      if (index > -1) /*check if the item is already selected*/ {
        _selectedItems.removeAt(index);
        if (widget.popupProps.onItemRemoved != null) {
          widget.popupProps.onItemRemoved!(_selectedItems, i);
        }
      }
    }
    _selectedItemsNotifier.value = List.from(_selectedItems);
  }

  ///close popup
  void closePopup() => Navigator.pop(context);

  void selectAllItems() => selectItems(_currentShowedItems);

  void deselectAllItems() => deselectItems(_selectedItems);

  bool get isAllItemSelected =>
      _listEquals(_selectedItems, _currentShowedItems);

  List<T> get getSelectedItem => List.from(_selectedItems);

  List<T> get getLoadedItems => List.from(_currentShowedItems);

  void addPinnedItem(T item) {
    if (widget.popupProps.pinnedItemsProps?.showPinnedItems != true ||
        _isDisabled(item) ||
        _itemIndexInList(pinnedItems, item) != -1) {
      return;
    }
    pinnedItems.add(item);
    _pinnedItemsDatabase.addItem(
      tag: widget.popupProps.pinnedItemsProps!.pinnedItemsTag,
      item: widget.popupProps.pinnedItemsProps!
          .pinnedItemsStringTransformer(item),
    );
    setState(() {});
  }

  void removePinnedItem(T item) {
    final props = widget.popupProps.pinnedItemsProps;
    if (props == null) return;
    final index = _itemIndexInList(pinnedItems, item);
    if (index == -1) return;
    final pinnedItem = pinnedItems.removeAt(index);
    _pinnedItemsDatabase.deleteItem(
      tag: props.pinnedItemsTag,
      item: props.pinnedItemsStringTransformer(pinnedItem),
    );
    setState(() {});
  }

  bool _listEquals(List<T>? a, List<T>? b) {
    if (a == null) {
      return b == null;
    }
    if (b == null || a.length != b.length) {
      return false;
    }
    if (identical(a, b)) {
      return true;
    }
    for (int index = 0; index < b.length; index += 1) {
      if (_itemIndexInList(a, b[index]) == -1) {
        return false;
      }
    }
    return true;
  }

  Widget _buildPinnedItemTrailing(T item) {
    if (_isPinned(item)) {
      return IconButton(
        onPressed: () => removePinnedItem(item),
        icon: Icon(Icons.star),
      );
    } else {
      return IconButton(
        onPressed: _isDisabled(item) ? null : () => addPinnedItem(item),
        icon: Icon(Icons.star_border),
      );
    }
  }
}
