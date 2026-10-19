import 'package:flutter/widgets.dart';

import 'library.dart';
import 'settings.dart';

class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope(
      {super.key, required AppSettings super.notifier, required super.child});

  /// Rebuilds the caller when settings change.
  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;

  static AppSettings read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}

class LibraryScope extends InheritedNotifier<DocLibrary> {
  const LibraryScope(
      {super.key, required DocLibrary super.notifier, required super.child});

  /// Rebuilds the caller when the library changes.
  static DocLibrary of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LibraryScope>()!.notifier!;

  static DocLibrary read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LibraryScope>()!.notifier!;
}
