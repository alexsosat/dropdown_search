import 'package:flutter/material.dart';

/// Optional decoration for list row content (e.g. [ListTile]-style layout).
class ItemProps<T> {
  /// Primary line (e.g. [Text] or [RichText]).
  final Widget Function(T item) title;

  /// Secondary line below [title].
  final Widget Function(T item)? subtitle;

  /// Widget shown before [title] / [subtitle] (e.g. icon or avatar).
  final Widget Function(T item)? leading;

  const ItemProps({
    required this.title,
    this.leading,
    this.subtitle,
  });
}
