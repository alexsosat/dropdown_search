/// Controls when the dropdown invokes its items callback.
enum ItemsLoadMode {
  /// Only an explicit call to `DropdownSearchState.loadItems` loads items.
  manual,

  /// Load items every time the popup opens (the default behavior).
  onOpen,

  /// Load on the first opening, then search and reopen using cached items.
  /// Failed initial loads are retried on the next opening.
  onFirstOpen,
}
