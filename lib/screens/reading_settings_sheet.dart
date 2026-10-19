import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/direction.dart';
import '../core/scopes.dart';
import '../core/settings.dart';
import '../core/strings.dart';
import '../core/themes.dart';

/// Opens the reading settings. Pass [zoom] and [onZoomChanged] from the reader
/// to show the zoom slider for the open file.
Future<void> showReadingSettings(
  BuildContext context, {
  ValueListenable<double>? zoom,
  ValueChanged<double>? onZoomChanged,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      barrierColor: Colors.black26,
      builder: (_) =>
          ReadingSettingsSheet(zoom: zoom, onZoomChanged: onZoomChanged),
    );

class ReadingSettingsSheet extends StatelessWidget {
  const ReadingSettingsSheet({super.key, this.zoom, this.onZoomChanged});

  final ValueListenable<double>? zoom;
  final ValueChanged<double>? onZoomChanged;

  /// 3 Arabic words out of 7 (43%): LTR at the default 50%, RTL at 43% or less.
  static const _sample = 'افتح ملف README.md من the main branch';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final st = SettingsScope.of(context);
    final p = ReaderPalette.of(context);
    final sampleDir = st.resolver.resolve(_sample);
    final isAuto = st.directionMode == DirectionMode.auto;

    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Label(s.direction),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<DirectionMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: DirectionMode.auto, label: Text(s.auto)),
                  ButtonSegment(value: DirectionMode.rtl, label: Text(s.rtl)),
                  ButtonSegment(value: DirectionMode.ltr, label: Text(s.ltr)),
                ],
                selected: {st.directionMode},
                onSelectionChanged: (v) =>
                    st.update((x) => x.directionMode = v.first),
              ),
            ),
            _Label('${s.sensitivity}: ${st.threshold.round()}%'),
            Text(s.sensitivityHelp,
                style: TextStyle(color: p.muted, fontSize: 13)),
            Slider(
              value: st.threshold,
              min: 0,
              max: 50,
              divisions: 50,
              label: '${st.threshold.round()}%',
              onChanged:
                  isAuto ? (v) => st.update((x) => x.threshold = v) : null,
            ),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: sampleDir == TextDirection.rtl ? p.accent : p.card,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sampleDir == TextDirection.rtl ? 'RTL' : 'LTR',
                  style: TextStyle(
                    fontSize: 12,
                    color: sampleDir == TextDirection.rtl ? p.background : p.text,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: p.card, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    _sample,
                    textDirection: sampleDir,
                    style: GoogleFonts.getFont(st.font,
                        textStyle: TextStyle(fontSize: 14, color: p.text)),
                  ),
                ),
              ),
            ]),
            _Label(s.font),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in AppSettings.fonts)
                ChoiceChip(
                  label: Text(s.fontName(f), style: GoogleFonts.getFont(f)),
                  selected: st.font == f,
                  onSelected: (_) => st.update((x) => x.font = f),
                ),
            ]),
            _SliderRow(
              label: s.fontSize,
              value: st.fontSize,
              min: 12,
              max: 40,
              divisions: 28,
              display: st.fontSize.round().toString(),
              onChanged: (v) => st.update((x) => x.fontSize = v),
            ),
            if (zoom != null && onZoomChanged != null)
              ValueListenableBuilder<double>(
                valueListenable: zoom!,
                builder: (context, z, _) => _SliderRow(
                  label: s.fileZoom,
                  value: z,
                  min: AppSettings.minZoom,
                  max: AppSettings.maxZoom,
                  divisions: 19,
                  // Zoom and the resulting text size, e.g. "120% (22)".
                  display: '${(z * 100).round()}% (${(st.fontSize * z).round()})',
                  onChanged: onZoomChanged!,
                ),
              ),
            _SliderRow(
              label: s.lineSpacing,
              value: st.lineHeight,
              min: 1.2,
              max: 2.4,
              divisions: 12,
              display: st.lineHeight.toStringAsFixed(1),
              onChanged: (v) => st.update((x) => x.lineHeight = v),
            ),
            _SliderRow(
              label: s.margins,
              value: st.margin,
              min: 4,
              max: 40,
              divisions: 18,
              display: st.margin.round().toString(),
              onChanged: (v) => st.update((x) => x.margin = v),
            ),
            _Label(s.theme),
            Wrap(spacing: 14, runSpacing: 8, children: [
              for (final t in AppSettings.themes)
                _ThemeDot(
                  name: t,
                  label: s.themeName(t),
                  selected: st.theme == t,
                  onTap: () => st.update((x) => x.theme = t),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ReaderPalette.of(context).text)),
      );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label('$label: $display'),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      );
}

class _ThemeDot extends StatelessWidget {
  const _ThemeDot({
    required this.name,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = ReaderPalette.of(context);
    final p = palettes[name];
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p?.background ?? current.card,
            border: Border.all(
              color: selected ? current.accent : current.line,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: p == null
              ? Icon(Icons.brightness_auto, color: current.muted, size: 20)
              : (selected ? Icon(Icons.check, color: p.accent, size: 20) : null),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: current.text)),
      ]),
    );
  }
}
