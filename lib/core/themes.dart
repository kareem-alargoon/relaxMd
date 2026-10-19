import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reading colors for one theme, available through `ReaderPalette.of`.
@immutable
class ReaderPalette extends ThemeExtension<ReaderPalette> {
  const ReaderPalette({
    required this.brightness,
    required this.background,
    required this.text,
    required this.muted,
    required this.accent,
    required this.card,
    required this.line,
    required this.highlight,
    required this.currentHighlight,
  });

  final Brightness brightness;
  final Color background;
  final Color text;
  final Color muted;
  final Color accent;
  final Color card;
  final Color line;
  final Color highlight;
  final Color currentHighlight;

  static ReaderPalette of(BuildContext context) =>
      Theme.of(context).extension<ReaderPalette>() ?? palettes['paper']!;

  @override
  ReaderPalette copyWith() => this;

  @override
  ReaderPalette lerp(ThemeExtension<ReaderPalette>? other, double t) =>
      (other is ReaderPalette && t >= 0.5) ? other : this;
}

const Map<String, ReaderPalette> palettes = {
  'paper': ReaderPalette(
    brightness: Brightness.light,
    background: Color(0xFFF7F3EA),
    text: Color(0xFF2A2723),
    muted: Color(0xFF8C8577),
    accent: Color(0xFF2F6F62),
    card: Color(0xFFEFE9DC),
    line: Color(0xFFE2DACB),
    highlight: Color(0xFFF2D98B),
    currentHighlight: Color(0xFFF0A830),
  ),
  'sepia': ReaderPalette(
    brightness: Brightness.light,
    background: Color(0xFFF1E6D0),
    text: Color(0xFF4A3B2A),
    muted: Color(0xFF8E7A60),
    accent: Color(0xFF8A5A2B),
    card: Color(0xFFE8DAC0),
    line: Color(0xFFDCCBAE),
    highlight: Color(0xFFEBC97A),
    currentHighlight: Color(0xFFE09A3A),
  ),
  'dim': ReaderPalette(
    brightness: Brightness.dark,
    background: Color(0xFF1C1D1F),
    text: Color(0xFFD8D3C8),
    muted: Color(0xFF8E8A82),
    accent: Color(0xFF6FB3A3),
    card: Color(0xFF26282B),
    line: Color(0xFF33363A),
    highlight: Color(0xFF5C4B1A),
    currentHighlight: Color(0xFF9A6B12),
  ),
  'night': ReaderPalette(
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    text: Color(0xFFB8B2A6),
    muted: Color(0xFF77736B),
    accent: Color(0xFF5E9C8F),
    card: Color(0xFF111111),
    line: Color(0xFF222222),
    highlight: Color(0xFF4A3C12),
    currentHighlight: Color(0xFF8A5E0E),
  ),
};

ThemeData buildTheme(ReaderPalette p) {
  final light = p.brightness == Brightness.light;
  final scheme =
      ColorScheme.fromSeed(seedColor: p.accent, brightness: p.brightness)
          .copyWith(
    primary: p.accent,
    onPrimary: light ? const Color(0xFFF7F3EA) : const Color(0xFF0F1A17),
    surface: p.background,
    onSurface: p.text,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: p.background,
    textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
    dividerColor: p.line,
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.background,
      surfaceTintColor: Colors.transparent,
    ),
    drawerTheme: DrawerThemeData(backgroundColor: p.background),
    extensions: [p],
  );
}
