import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;

import '../core/arabic_search.dart';
import '../core/library.dart';
import '../core/scopes.dart';
import '../core/settings.dart';
import '../core/strings.dart';
import '../core/themes.dart';
import '../markdown/md_renderer.dart';
import 'editor_screen.dart';
import 'reading_settings_sheet.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.entry});

  final DocEntry entry;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const _minZoom = AppSettings.minZoom;
  static const _maxZoom = AppSettings.maxZoom;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  /// Holds focus for the keyboard shortcuts while nothing else has it.
  final _keysFocus = FocusNode();
  final _keyPool = <GlobalKey>[];
  late DocLibrary _library;

  String _source = '';
  List<md.Node> _nodes = const [];
  bool _loading = true;
  String? _error;

  /// Per-file zoom, shared with the reading settings sheet.
  late final _zoomNotifier = ValueNotifier<double>(widget.entry.zoom);
  double get _zoom => _zoomNotifier.value;

  bool _searching = false;
  String _query = '';
  int _current = 0;
  bool _caseSensitive = false;
  bool _wholeWord = false;
  RenderResult? _last;

  /// Side panels shown next to the text on a wide window (desktop).
  bool _showContents = true;
  bool _showSettings = false;

  /// Width from which the contents and settings sit beside the text.
  static const _wideLayout = 1000.0;

  /// Longest comfortable line; wider windows get bigger side margins.
  static const _maxTextWidth = 860.0;

  // Pinch-to-zoom is tracked by hand so it doesn't fight with scrolling.
  final Map<int, Offset> _pointers = {};
  bool _pinching = false;
  double _pinchStartDistance = 0;
  double _pinchStartZoom = 1;

  @override
  void initState() {
    super.initState();
    _load(restorePosition: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _library = LibraryScope.read(context);
  }

  @override
  void dispose() {
    _savePosition();
    _scroll.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _keysFocus.dispose();
    _zoomNotifier.dispose();
    super.dispose();
  }

  Future<void> _load({bool restorePosition = false}) async {
    try {
      final text = await readText(widget.entry.path);
      if (!mounted) return;
      setState(() {
        _source = text;
        _nodes = parseMarkdown(text);
        _loading = false;
        _error = null;
      });
      if (restorePosition) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scroll.hasClients) return;
          final max = _scroll.position.maxScrollExtent;
          _scroll.jumpTo(widget.entry.scrollOffset.clamp(0.0, max).toDouble());
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _savePosition() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    final progress = pos.maxScrollExtent <= 0
        ? 1.0
        : (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0).toDouble();
    _library.savePosition(widget.entry, pos.pixels, progress);
  }

  void _setZoom(double z) {
    setState(
        () => _zoomNotifier.value = z.clamp(_minZoom, _maxZoom).toDouble());
    _library.setZoom(widget.entry, _zoom);
  }

  // Pinch handling

  double _pointerDistance() {
    final p = _pointers.values.take(2).toList();
    return (p[0] - p[1]).distance;
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      _pinchStartDistance = _pointerDistance();
      _pinchStartZoom = _zoom;
      setState(() => _pinching = true);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    if (!_pinching || _pointers.length < 2 || _pinchStartDistance <= 0) return;
    final z = (_pinchStartZoom * _pointerDistance() / _pinchStartDistance)
        .clamp(_minZoom, _maxZoom)
        .toDouble();
    if ((z - _zoom).abs() > 0.02) setState(() => _zoomNotifier.value = z);
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pinching && _pointers.length < 2) {
      setState(() => _pinching = false);
      _library.setZoom(widget.entry, _zoom);
    }
  }

  /// Ctrl + mouse wheel zooms instead of scrolling.
  void _onPointerSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent ||
        !HardwareKeyboard.instance.isControlPressed) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final dy = (event as PointerScrollEvent).scrollDelta.dy;
      _setZoom(_zoom + (dy < 0 ? 0.1 : -0.1));
    });
  }

  // Search

  void _openSearch() {
    setState(() => _searching = true);
    _searchFocus.requestFocus();
  }

  void _toggleContents(bool wide) {
    if (wide) {
      setState(() => _showContents = !_showContents);
    } else {
      _scaffoldKey.currentState?.openEndDrawer();
    }
  }

  void _toggleSettings(bool wide) {
    if (wide) {
      setState(() => _showSettings = !_showSettings);
    } else {
      showReadingSettings(context, zoom: _zoomNotifier, onZoomChanged: _setZoom);
    }
  }

  /// Esc closes search first, then the settings panel, then the file.
  void _escape() {
    if (_searching) {
      _closeSearch();
    } else if (_showSettings) {
      setState(() => _showSettings = false);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _zoomBy(double delta) => _setZoom(_zoom + delta);

  Map<ShortcutActivator, VoidCallback> _shortcuts(bool wide) => {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _openSearch,
        const SingleActivator(LogicalKeyboardKey.f3): () => _step(1),
        const SingleActivator(LogicalKeyboardKey.f3, shift: true): () =>
            _step(-1),
        const SingleActivator(LogicalKeyboardKey.escape): _escape,
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): _edit,
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): () =>
            Navigator.of(context).maybePop(),
        const SingleActivator(LogicalKeyboardKey.f5): _load,
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
            _zoomBy(0.1),
        const SingleActivator(LogicalKeyboardKey.equal,
            control: true, shift: true): () => _zoomBy(0.1),
        const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true):
            () => _zoomBy(0.1),
        const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
            _zoomBy(-0.1),
        const SingleActivator(LogicalKeyboardKey.numpadSubtract,
            control: true): () => _zoomBy(-0.1),
        const SingleActivator(LogicalKeyboardKey.digit0, control: true): () =>
            _setZoom(1),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
            _toggleContents(wide),
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            _toggleSettings(wide),
      };

  void _closeSearch() {
    _keysFocus.requestFocus();
    setState(() {
      _searching = false;
      _query = '';
      _current = 0;
    });
    _searchCtrl.clear();
  }

  void _onQuery(String q) {
    setState(() {
      _query = q;
      _current = 0;
    });
    _scrollToCurrent();
  }

  void _step(int delta) {
    final total = _last?.matchCount ?? 0;
    if (total == 0) return;
    setState(() => _current = (_current + delta) % total);
    _scrollToCurrent();
  }

  void _scrollToCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keys = _last?.matchKeys ?? const <GlobalKey>[];
      if (keys.isEmpty) return;
      final ctx = keys[_current < keys.length ? _current : 0].currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 250),
            alignment: 0.2,
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _edit() async {
    _savePosition();
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => EditorScreen(entry: widget.entry)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final settings = SettingsScope.of(context);
    final palette = ReaderPalette.of(context);
    final resolver = settings.resolver;

    final result = MdRenderer(
      palette: palette,
      bodyStyle: TextStyle(
        fontSize: settings.fontSize * _zoom,
        height: settings.lineHeight,
        color: palette.text,
      ),
      applyFont: (st) => GoogleFonts.getFont(settings.font, textStyle: st),
      resolver: resolver,
      documentDirection: resolver.resolve(_source),
      query: _searching ? _query : '',
      searchOptions:
          SearchOptions(caseSensitive: _caseSensitive, wholeWord: _wholeWord),
      currentMatch: _current,
      keyPool: _keyPool,
    ).render(_nodes);
    _last = result;
    final wide = isDesktop && MediaQuery.sizeOf(context).width >= _wideLayout;

    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Center(child: Text('${s.openFailed}\n$_error'))
            : Stack(children: [
                Positioned.fill(child: _content(s, settings.margin, result)),
                PositionedDirectional(
                  start: 16,
                  bottom: 20,
                  child: _zoomChip(palette),
                ),
              ]);

    final screen = Scaffold(
      key: _scaffoldKey,
      appBar: _searching ? _searchBar(s, result) : _mainBar(s, wide),
      endDrawer: wide ? null : _contentsDrawer(s, result),
      floatingActionButton: _searching
          ? null
          : FloatingActionButton.extended(
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
              label: Text(s.edit),
            ),
      body: wide ? _wideBody(s, palette, result, body) : body,
    );

    if (!isDesktop) return screen;
    return CallbackShortcuts(
      bindings: _shortcuts(wide),
      child: Focus(focusNode: _keysFocus, autofocus: true, child: screen),
    );
  }

  /// Contents on one side, reading settings on the other, text in between.
  Widget _wideBody(
          S s, ReaderPalette palette, RenderResult result, Widget body) =>
      Row(children: [
        if (_showContents) ...[
          SizedBox(
            width: 280,
            child: Material(
                color: palette.card,
                child: _contentsList(s, result, inDrawer: false)),
          ),
          VerticalDivider(width: 1, color: palette.line),
        ],
        Expanded(child: body),
        if (_showSettings) ...[
          VerticalDivider(width: 1, color: palette.line),
          SizedBox(
            width: 360,
            child: Material(
              color: palette.card,
              child: Column(children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: s.hidePanel,
                    onPressed: () => setState(() => _showSettings = false),
                  ),
                ),
                Expanded(
                  child: ReadingSettingsSheet(
                      zoom: _zoomNotifier, onZoomChanged: _setZoom),
                ),
              ]),
            ),
          ),
        ],
      ]);

  PreferredSizeWidget _mainBar(S s, bool wide) => AppBar(
        title: Text(widget.entry.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
              icon: const Icon(Icons.search),
              tooltip: s.search,
              onPressed: _openSearch),
          IconButton(
              icon: const Icon(Icons.toc),
              tooltip: s.contents,
              onPressed: () => _toggleContents(wide)),
          IconButton(
              icon: const Text('Aa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              tooltip: s.readingSettings,
              onPressed: () => _toggleSettings(wide)),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reload') {
                _load();
              } else if (v == 'fav') {
                _library.toggleFavorite(widget.entry);
                setState(() {});
              } else if (v == 'zoom') {
                _setZoom(1);
              }
            },
            itemBuilder: (_) => [
              if (isDesktop)
                PopupMenuItem(value: 'reload', child: Text(s.reload)),
              PopupMenuItem(
                  value: 'fav',
                  child: Text(widget.entry.favorite ? s.unfavorite : s.favorite)),
              PopupMenuItem(value: 'zoom', child: Text(s.resetZoom)),
            ],
          ),
        ],
      );

  PreferredSizeWidget _searchBar(S s, RenderResult result) {
    final total = result.matchCount;
    final shown = total == 0 ? 0 : (_current < total ? _current : 0) + 1;
    return AppBar(
      leading: IconButton(
          icon: const Icon(Icons.close), tooltip: s.close, onPressed: _closeSearch),
      title: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onChanged: _onQuery,
        onSubmitted: (_) => _step(1),
        textInputAction: TextInputAction.search,
        decoration:
            InputDecoration(hintText: s.searchHint, border: InputBorder.none),
      ),
      actions: [
        Center(child: Text(s.counter(shown, total))),
        IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: () => _step(-1)),
        IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => _step(1)),
        PopupMenuButton<String>(
          icon: const Icon(Icons.tune),
          onSelected: (v) => setState(() {
            if (v == 'case') _caseSensitive = !_caseSensitive;
            if (v == 'word') _wholeWord = !_wholeWord;
            _current = 0;
          }),
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
                value: 'case', checked: _caseSensitive, child: Text(s.caseSensitive)),
            CheckedPopupMenuItem(
                value: 'word', checked: _wholeWord, child: Text(s.wholeWord)),
          ],
        ),
      ],
    );
  }

  Widget _content(S s, double margin, RenderResult result) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: result.blocks.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Text(s.emptyDoc, textAlign: TextAlign.center),
              )
            ]
          : result.blocks,
    );
    return LayoutBuilder(builder: (context, constraints) {
      // On a wide window the text keeps a comfortable line length.
      final side = isDesktop
          ? ((constraints.maxWidth - _maxTextWidth) / 2)
              .clamp(margin, double.infinity)
              .toDouble()
          : margin;
      return Listener(
        onPointerSignal: isDesktop ? _onPointerSignal : null,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            _savePosition();
            return false;
          },
          child: Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              controller: _scroll,
              physics: _pinching ? const NeverScrollableScrollPhysics() : null,
              padding: EdgeInsets.fromLTRB(side, 12, side, 120),
              // Text can be selected and copied with the mouse on the desktop.
              child: isDesktop ? SelectionArea(child: column) : column,
            ),
          ),
        ),
      );
    });
  }

  Widget _zoomChip(ReaderPalette palette) => Material(
        color: palette.card,
        shape: const StadiumBorder(),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
            onPressed: () => _setZoom(_zoom - 0.1),
          ),
          GestureDetector(
            onTap: () => _setZoom(1),
            child: Text('${(_zoom * 100).round()}%',
                style: TextStyle(color: palette.text)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => _setZoom(_zoom + 0.1),
          ),
        ]),
      );

  Widget _contentsDrawer(S s, RenderResult result) => Drawer(
        child: SafeArea(child: _contentsList(s, result, inDrawer: true)),
      );

  Widget _contentsList(S s, RenderResult result, {required bool inDrawer}) =>
      result.headings.isEmpty
              ? Center(child: Text(s.noHeadings))
              : ListView(children: [
                  ListTile(
                    title: Text(s.contents,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  for (final h in result.headings)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsetsDirectional.only(
                          start: 16.0 + (h.level - 1) * 14, end: 16),
                      title: Text(h.text,
                          textDirection: h.direction,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      onTap: () {
                        if (inDrawer) {
                          _scaffoldKey.currentState?.closeEndDrawer();
                        }
                        final ctx = h.key.currentContext;
                        if (ctx != null) {
                          Scrollable.ensureVisible(ctx,
                              duration: const Duration(milliseconds: 300),
                              alignment: 0.05);
                        }
                      },
                    ),
                ]);
}
