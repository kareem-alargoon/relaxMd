import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/arabic_search.dart';
import '../core/library.dart';
import '../core/scopes.dart';
import '../core/strings.dart';
import '../core/themes.dart';
import '../markdown/markdown_editing_controller.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.entry});

  final DocEntry entry;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final _ctrl = MarkdownEditingController();
  final _undo = UndoHistoryController();
  final _focus = FocusNode();
  final _findCtrl = TextEditingController();
  final _replaceCtrl = TextEditingController();
  static final _wordPattern = RegExp(r'\S+');

  Timer? _saveTimer;
  String _savedText = '';
  bool _loading = true;
  bool _saving = false;
  bool _finding = false;
  List<MatchRange> _matches = const [];
  int _current = 0;

  bool get _dirty => _ctrl.text != _savedText;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final text = await readText(widget.entry.path);
    if (!mounted) return;
    _savedText = text;
    _ctrl.text = text;
    _ctrl.addListener(_onChanged);
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Last-chance save when leaving with the back button.
    if (!_loading && _dirty) {
      File(widget.entry.path).writeAsStringSync(_ctrl.text);
    }
    _ctrl.dispose();
    _undo.dispose();
    _focus.dispose();
    _findCtrl.dispose();
    _replaceCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_finding) _recomputeMatches();
    if (_dirty) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 1200), _save);
    }
    setState(() {});
  }

  Future<void> _save() async {
    final text = _ctrl.text;
    if (text == _savedText) return;
    setState(() => _saving = true);
    await File(widget.entry.path).writeAsString(text);
    _savedText = text;
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _done() async {
    _saveTimer?.cancel();
    await _save();
    if (mounted) Navigator.of(context).pop();
  }

  // Find and replace

  void _recomputeMatches() {
    _matches = ArabicSearch.find(_ctrl.text, _findCtrl.text);
    if (_current >= _matches.length) _current = 0;
    _ctrl.matches = _matches;
    _ctrl.currentMatch = _current;
  }

  void _openFind() => setState(() {
        _finding = true;
        _recomputeMatches();
      });

  void _closeFind() => setState(() {
        _finding = false;
        _matches = const [];
        _ctrl.matches = const [];
      });

  void _goTo(int delta) {
    if (_matches.isEmpty) return;
    setState(() {
      _current = (_current + delta) % _matches.length;
      _ctrl.currentMatch = _current;
    });
    final m = _matches[_current];
    _focus.requestFocus();
    _ctrl.selection = TextSelection(baseOffset: m.start, extentOffset: m.end);
  }

  void _replaceCurrent() {
    if (_matches.isEmpty) return;
    final m = _matches[_current];
    final rep = _replaceCtrl.text;
    _ctrl.value = TextEditingValue(
      text: _ctrl.text.replaceRange(m.start, m.end, rep),
      selection: TextSelection.collapsed(offset: m.start + rep.length),
    );
  }

  void _replaceAll() {
    if (_matches.isEmpty) return;
    final count = _matches.length;
    final rep = _replaceCtrl.text;
    var text = _ctrl.text;
    for (final m in _matches.reversed) {
      text = text.replaceRange(m.start, m.end, rep);
    }
    _ctrl.value = TextEditingValue(
        text: text, selection: const TextSelection.collapsed(offset: 0));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.of(context).replaced(count))));
  }

  // Toolbar actions

  TextSelection get _selection {
    final sel = _ctrl.selection;
    return sel.isValid ? sel : TextSelection.collapsed(offset: _ctrl.text.length);
  }

  void _wrap(String left, String right) {
    final sel = _selection;
    final text = _ctrl.text;
    final inner = text.substring(sel.start, sel.end);
    _ctrl.value = TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, '$left$inner$right'),
      selection: TextSelection(
        baseOffset: sel.start + left.length,
        extentOffset: sel.start + left.length + inner.length,
      ),
    );
    _focus.requestFocus();
  }

  void _prefixLine(String prefix) {
    final sel = _selection;
    final text = _ctrl.text;
    final lineStart = sel.start == 0 ? 0 : text.lastIndexOf('\n', sel.start - 1) + 1;
    _ctrl.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineStart, prefix),
      selection: TextSelection.collapsed(offset: sel.end + prefix.length),
    );
    _focus.requestFocus();
  }

  void _insertBlock(String block) {
    final sel = _selection;
    final text = _ctrl.text;
    final needsBreak = sel.start > 0 && text[sel.start - 1] != '\n';
    final insert = '${needsBreak ? '\n' : ''}$block';
    _ctrl.value = TextEditingValue(
      text: text.replaceRange(sel.start, sel.end, insert),
      selection: TextSelection.collapsed(offset: sel.start + insert.length),
    );
    _focus.requestFocus();
  }

  void _code() {
    final sel = _selection;
    if (_ctrl.text.substring(sel.start, sel.end).contains('\n')) {
      _wrap('```\n', '\n```');
    } else {
      _wrap('`', '`');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = SettingsScope.of(context);
    final palette = ReaderPalette.of(context);
    _ctrl
      ..accent = palette.accent
      ..muted = palette.muted
      ..highlight = palette.highlight
      ..currentHighlight = palette.currentHighlight;

    final text = _ctrl.text;
    final words = _wordPattern.allMatches(text).length;
    final busy = _dirty || _saving;

    return Scaffold(
      appBar: _finding ? _findBar(s) : _mainBar(s),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(children: [
                  Icon(busy ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
                      size: 16, color: palette.muted),
                  const SizedBox(width: 6),
                  Text(busy ? s.saving : s.saved,
                      style: TextStyle(fontSize: 12, color: palette.muted)),
                  const Spacer(),
                  Text(s.words(words, text.length),
                      style: TextStyle(fontSize: 12, color: palette.muted)),
                ]),
              ),
              if (_finding) _replaceRow(s),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: settings.margin),
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    undoController: _undo,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    keyboardType: TextInputType.multiline,
                    textDirection: settings.resolver.resolve(text),
                    textAlignVertical: TextAlignVertical.top,
                    cursorColor: palette.accent,
                    style: GoogleFonts.getFont(settings.font,
                        textStyle: TextStyle(
                            fontSize: settings.fontSize * 0.95,
                            height: 1.7,
                            color: palette.text)),
                    decoration: InputDecoration.collapsed(hintText: s.editorHint),
                  ),
                ),
              ),
              _toolbar(s, palette),
            ]),
    );
  }

  PreferredSizeWidget _mainBar(S s) => AppBar(
        leading: IconButton(
            icon: const Icon(Icons.check), tooltip: s.done, onPressed: _done),
        title: Text(widget.entry.name, overflow: TextOverflow.ellipsis),
        actions: [
          ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: _undo,
            builder: (context, v, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: s.undo,
                  onPressed: v.canUndo ? _undo.undo : null),
              IconButton(
                  icon: const Icon(Icons.redo),
                  tooltip: s.redo,
                  onPressed: v.canRedo ? _undo.redo : null),
            ]),
          ),
          IconButton(
              icon: const Icon(Icons.find_replace),
              tooltip: s.findReplace,
              onPressed: _openFind),
        ],
      );

  PreferredSizeWidget _findBar(S s) => AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close), tooltip: s.close, onPressed: _closeFind),
        title: TextField(
          controller: _findCtrl,
          autofocus: true,
          decoration: InputDecoration(hintText: s.find, border: InputBorder.none),
          onChanged: (_) => setState(() {
            _current = 0;
            _recomputeMatches();
          }),
          onSubmitted: (_) => _goTo(1),
        ),
        actions: [
          Center(
              child: Text(s.counter(
                  _matches.isEmpty ? 0 : _current + 1, _matches.length))),
          IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: () => _goTo(-1)),
          IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: () => _goTo(1)),
        ],
      );

  Widget _replaceRow(S s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _replaceCtrl,
              decoration: InputDecoration(hintText: s.replaceWith, isDense: true),
            ),
          ),
          TextButton(onPressed: _replaceCurrent, child: Text(s.replace)),
          TextButton(onPressed: _replaceAll, child: Text(s.replaceAll)),
        ]),
      );

  Widget _toolbar(S s, ReaderPalette palette) {
    Widget button(IconData icon, String tip, VoidCallback onTap) =>
        IconButton(icon: Icon(icon), tooltip: tip, onPressed: onTap);
    return Material(
      color: palette.card,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            button(Icons.format_bold, s.bold, () => _wrap('**', '**')),
            button(Icons.format_italic, s.italic, () => _wrap('*', '*')),
            button(Icons.title, s.heading, () => _prefixLine('# ')),
            button(Icons.format_list_bulleted, s.bulletList, () => _prefixLine('- ')),
            button(Icons.format_list_numbered, s.numberedList, () => _prefixLine('1. ')),
            button(Icons.check_box_outlined, s.checkbox, () => _prefixLine('- [ ] ')),
            button(Icons.format_quote, s.quote, () => _prefixLine('> ')),
            button(Icons.link, s.link, () => _wrap('[', '](https://)')),
            button(Icons.table_chart_outlined, s.table,
                () => _insertBlock('| A | B |\n|---|---|\n|   |   |\n')),
            button(Icons.code, s.code, _code),
          ]),
        ),
      ),
    );
  }
}
