import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/library.dart';
import '../core/scopes.dart';
import '../core/strings.dart';
import '../core/themes.dart';
import '../desktop/desktop_shell.dart';
import 'editor_screen.dart';
import 'reader_screen.dart';
import 'reading_settings_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialFile});

  /// A file to open as soon as the screen is up (from the command line).
  final String? initialFile;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final file = widget.initialFile;
    if (file != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPath(file));
    }
  }

  Future<void> _open(DocEntry entry) async {
    LibraryScope.read(context).touch(entry);
    await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ReaderScreen(entry: entry)));
    // Refresh reading progress shown on the cards.
    if (mounted) setState(() {});
  }

  Future<void> _openFile() async {
    final s = S.of(context);
    final library = LibraryScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (isDesktop) {
        final result = await FilePicker.platform.pickFiles(
            type: FileType.custom, allowedExtensions: markdownExtensions);
        final path = result?.files.single.path;
        if (path != null) await _openPath(path);
        return;
      }
      final result =
          await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      final file = result?.files.single;
      if (file == null) return;
      final bytes = file.bytes ??
          (file.path != null ? await File(file.path!).readAsBytes() : null);
      if (bytes == null) throw const FileSystemException('No data');
      final entry = await library.importText(file.name, decodeText(bytes));
      if (mounted) await _open(entry);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${s.openFailed}: $e')));
    }
  }

  /// Opens a file in place (desktop): picked or from the command line.
  Future<void> _openPath(String path) async {
    await openInPlace(context, path);
    // Refresh reading progress shown on the cards.
    if (mounted) setState(() {});
  }

  Future<void> _newFile() async {
    final s = S.of(context);
    final library = LibraryScope.read(context);
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.newFile),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: s.fileName),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(s.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(ctrl.text),
              child: Text(s.create)),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty) return;
    final entry = isDesktop
        ? await _saveNewFile(name)
        : await library.createNew(name);
    if (entry == null) return;
    if (!mounted) return;
    await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => EditorScreen(entry: entry)));
    if (mounted) await _open(entry);
  }

  /// Asks where to save a new file and creates it there (desktop).
  Future<DocEntry?> _saveNewFile(String name) async {
    final path = await FilePicker.platform.saveFile(
      fileName: DocLibrary.sanitize(name),
      type: FileType.custom,
      allowedExtensions: markdownExtensions,
    );
    if (path == null) return null;
    final file = File(isMarkdownPath(path) ? path : '$path.md');
    if (!file.existsSync()) await file.writeAsString('');
    if (!mounted) return null;
    return LibraryScope.read(context).openPath(file.path);
  }

  Future<void> _actions(DocEntry entry) async {
    final s = S.of(context);
    final library = LibraryScope.read(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Icon(entry.favorite ? Icons.star : Icons.star_border),
            title: Text(entry.favorite ? s.unfavorite : s.favorite),
            onTap: () => Navigator.of(context).pop('fav'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(s.remove),
            onTap: () => Navigator.of(context).pop('remove'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    if (action == 'fav') {
      library.toggleFavorite(entry);
    } else if (action == 'remove') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.removeTitle),
          content: Text(isDesktop ? s.removeBodyDesktop : s.removeBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(s.cancel)),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(s.remove)),
          ],
        ),
      );
      if (ok == true) await library.remove(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final palette = ReaderPalette.of(context);
    final library = LibraryScope.of(context);
    final recent = library.recent;
    final favorites = library.favorites;

    final screen = Scaffold(
      appBar: AppBar(
        title: Text('RelaxMD',
            style: TextStyle(color: palette.accent, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: s.readingSettings,
            onPressed: () => showReadingSettings(context),
          ),
        ],
      ),
      body: recent.isEmpty
          ? _emptyState(s, palette)
          : ListView(
              padding: _listPadding(context),
              children: [
                if (favorites.isNotEmpty) ...[
                  _section(s.favorites, palette),
                  for (final e in favorites) _card(s, palette, e),
                ],
                _section(s.recent, palette),
                for (final e in recent) _card(s, palette, e),
              ],
            ),
      floatingActionButton: recent.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: [
              FloatingActionButton.extended(
                heroTag: 'open',
                onPressed: _openFile,
                icon: const Icon(Icons.folder_open),
                label: Text(s.openFile),
              ),
              const SizedBox(width: 12),
              FloatingActionButton.small(
                heroTag: 'new',
                tooltip: s.newFile,
                onPressed: _newFile,
                child: const Icon(Icons.add),
              ),
            ]),
    );

    if (!isDesktop) return screen;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): _openFile,
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _newFile,
      },
      child: Focus(autofocus: true, child: screen),
    );
  }

  /// Keeps the file list a readable width on a wide window.
  EdgeInsets _listPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final side = width > 760 ? (width - 720) / 2 : 16.0;
    return EdgeInsets.fromLTRB(side, 4, side, 120);
  }

  Widget _section(String title, ReaderPalette palette) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(title, style: TextStyle(color: palette.muted, fontSize: 13)),
      );

  Widget _card(S s, ReaderPalette palette, DocEntry e) => GestureDetector(
      // Right-click shows the same actions as a long press.
      onSecondaryTap: () => _actions(e),
      child: Card(
        elevation: 0,
        color: palette.card,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(
            e.favorite ? Icons.star : Icons.description_outlined,
            color: e.favorite ? palette.accent : palette.muted,
          ),
          title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${s.dateLabel(e.lastOpened)} · ${s.percentRead((e.progress * 100).round())}',
            style: TextStyle(color: palette.muted, fontSize: 12),
          ),
          onTap: () => _open(e),
          onLongPress: () => _actions(e),
        ),
      ));

  Widget _emptyState(S s, ReaderPalette palette) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.menu_book_outlined, size: 64, color: palette.accent),
            const SizedBox(height: 16),
            Text(s.emptyTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(isDesktop ? s.emptyBodyDesktop : s.emptyBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.muted)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _openFile,
              icon: const Icon(Icons.folder_open),
              label: Text(s.openFile),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _newFile,
              icon: const Icon(Icons.add),
              label: Text(s.newFile),
            ),
          ]),
        ),
      );
}
