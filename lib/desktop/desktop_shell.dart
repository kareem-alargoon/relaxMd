import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import '../core/library.dart';
import '../core/scopes.dart';
import '../core/strings.dart';
import '../core/themes.dart';
import '../screens/reader_screen.dart';

/// The app's navigator, so a file can be opened from anywhere (drop, startup).
final appNavigator = GlobalKey<NavigatorState>();

/// Opens the file at [path] in place and shows it in the reader, replacing any
/// file that is open now. Completes when the reader is closed.
Future<void> openInPlace(BuildContext context, String path) async {
  final navigator = appNavigator.currentState;
  if (navigator == null) return;
  if (!File(path).existsSync()) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('${S.of(context).openFailed}: $path')));
    return;
  }
  final entry = LibraryScope.read(context).openPath(path);
  navigator.popUntil((route) => route.isFirst);
  await navigator.push(
      MaterialPageRoute<void>(builder: (_) => ReaderScreen(entry: entry)));
}

/// Lets Markdown files be dropped onto the window from Explorer, on any screen.
class DesktopDropZone extends StatefulWidget {
  const DesktopDropZone({super.key, required this.child});

  final Widget child;

  @override
  State<DesktopDropZone> createState() => _DesktopDropZoneState();
}

class _DesktopDropZoneState extends State<DesktopDropZone> {
  bool _dragging = false;

  void _onDrop(DropDoneDetails details) {
    setState(() => _dragging = false);
    final path =
        details.files.map((f) => f.path).where(isMarkdownPath).firstOrNull;
    if (path != null) {
      openInPlace(context, path);
    } else if (details.files.isNotEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(S.of(context).notMarkdown)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final palette = ReaderPalette.of(context);
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: _onDrop,
      child: Stack(children: [
        widget.child,
        if (_dragging)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.background.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.accent, width: 2),
                ),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.file_download_outlined,
                        size: 56, color: palette.accent),
                    const SizedBox(height: 12),
                    Text(s.dropHere,
                        style: TextStyle(fontSize: 18, color: palette.text)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
