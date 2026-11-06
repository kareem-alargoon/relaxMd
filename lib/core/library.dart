import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String decodeText(List<int> bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);
  if (text.startsWith('﻿')) text = text.substring(1);
  return text;
}

Future<String> readText(String path) async =>
    decodeText(await File(path).readAsBytes());

String baseName(String path) => path.split(RegExp(r'[\\/]')).last;

/// On the desktop files are read and edited where they are; on the phone they
/// are copied into the app first.
bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// File types the app opens: from the picker, drag and drop or the command line.
const markdownExtensions = ['md', 'markdown', 'txt'];

bool isMarkdownPath(String path) {
  final dot = path.lastIndexOf('.');
  return dot >= 0 &&
      markdownExtensions.contains(path.substring(dot + 1).toLowerCase());
}

class DocEntry {
  DocEntry({
    required this.path,
    required this.lastOpened,
    this.favorite = false,
    this.scrollOffset = 0,
    this.progress = 0,
    this.zoom = 1,
  });

  factory DocEntry.fromJson(Map<String, dynamic> j) => DocEntry(
        path: j['path'] as String,
        lastOpened:
            DateTime.fromMillisecondsSinceEpoch(j['lastOpened'] as int),
        favorite: j['favorite'] as bool? ?? false,
        scrollOffset: (j['scrollOffset'] as num?)?.toDouble() ?? 0,
        progress: (j['progress'] as num?)?.toDouble() ?? 0,
        zoom: (j['zoom'] as num?)?.toDouble() ?? 1,
      );

  final String path;
  DateTime lastOpened;
  bool favorite;
  double scrollOffset;

  /// Reading progress from 0 to 1.
  double progress;

  /// Per-file text zoom, multiplied with the font size setting.
  double zoom;

  String get name => baseName(path);

  Map<String, dynamic> toJson() => {
        'path': path,
        'lastOpened': lastOpened.millisecondsSinceEpoch,
        'favorite': favorite,
        'scrollOffset': scrollOffset,
        'progress': progress,
        'zoom': zoom,
      };
}

/// Recent files and favorites. On the phone, opened files are copied into the
/// app's own folder, so they can be edited and saved without storage
/// permissions. On the desktop they stay where they are ([openPath]).
class DocLibrary extends ChangeNotifier {
  DocLibrary(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  final List<DocEntry> _entries = [];
  static const _key = 'library';

  List<DocEntry> get recent =>
      [..._entries]..sort((a, b) => b.lastOpened.compareTo(a.lastOpened));

  List<DocEntry> get favorites => recent.where((e) => e.favorite).toList();

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      _entries.addAll(list
          .map((e) => DocEntry.fromJson(Map<String, dynamic>.from(e as Map))));
    } catch (_) {
      // Corrupt data: start with an empty list.
    }
    _entries.removeWhere((e) => !File(e.path).existsSync());
  }

  Future<void> _save() => _prefs.setString(
      _key, jsonEncode(_entries.map((e) => e.toJson()).toList()));

  static Future<Directory> docsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}docs');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  static String sanitize(String name) {
    var n = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (n.isEmpty) n = 'untitled';
    final lower = n.toLowerCase();
    if (!(lower.endsWith('.md') ||
        lower.endsWith('.markdown') ||
        lower.endsWith('.txt'))) {
      n = '$n.md';
    }
    return n;
  }

  /// Copies [content] into the app folder as [fileName]. Opening the same file
  /// again reuses the existing copy; a different file with the same name gets
  /// a numbered name.
  Future<DocEntry> importText(String fileName, String content) async {
    final dir = await docsDir();
    final clean = sanitize(fileName);
    final dot = clean.lastIndexOf('.');
    final stem = clean.substring(0, dot);
    final ext = clean.substring(dot);
    final sep = Platform.pathSeparator;
    var file = File('${dir.path}$sep$clean');
    var n = 2;
    while (file.existsSync()) {
      if (await readText(file.path) == content) break;
      file = File('${dir.path}$sep$stem ($n)$ext');
      n++;
    }
    if (!file.existsSync()) await file.writeAsString(content);
    return _register(file.path);
  }

  Future<DocEntry> createNew(String fileName) => importText(fileName, '');

  /// Opens the file at [path] in place (desktop), so edits go to the file itself.
  DocEntry openPath(String path) => _register(File(path).absolute.path);

  DocEntry _register(String path) {
    for (final e in _entries) {
      if (_samePath(e.path, path)) {
        touch(e);
        return e;
      }
    }
    final entry = DocEntry(path: path, lastOpened: DateTime.now());
    _entries.add(entry);
    notifyListeners();
    _save();
    return entry;
  }

  void touch(DocEntry entry) {
    entry.lastOpened = DateTime.now();
    notifyListeners();
    _save();
  }

  void toggleFavorite(DocEntry entry) {
    entry.favorite = !entry.favorite;
    notifyListeners();
    _save();
  }

  /// Removes the entry and deletes the app's copy. The original file the user
  /// opened is never touched: a file opened in place is only forgotten.
  Future<void> remove(DocEntry entry) async {
    _entries.remove(entry);
    notifyListeners();
    await _save();
    final dir = await docsDir();
    final inAppFolder = _samePath(File(entry.path).parent.path, dir.path);
    final file = File(entry.path);
    if (inAppFolder && file.existsSync()) await file.delete();
  }

  /// Windows paths are case-insensitive.
  static bool _samePath(String a, String b) => Platform.isWindows
      ? a.toLowerCase() == b.toLowerCase()
      : a == b;

  /// Saves without notifying, so it is safe to call while a screen closes.
  void savePosition(DocEntry entry, double offset, double progress) {
    entry.scrollOffset = offset;
    entry.progress = progress;
    _save();
  }

  void setZoom(DocEntry entry, double zoom) {
    entry.zoom = zoom;
    _save();
  }
}
