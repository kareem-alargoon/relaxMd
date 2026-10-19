import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'direction.dart';

/// Reading settings shared by the whole app, saved to SharedPreferences.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  static const fonts = ['Noto Naskh Arabic', 'Amiri', 'Cairo', 'Tajawal'];
  static const themes = ['system', 'paper', 'sepia', 'dim', 'night'];

  /// Limits for the per-file zoom, which multiplies [fontSize].
  static const minZoom = 0.6;
  static const maxZoom = 2.5;

  String theme = 'system';
  String font = fonts.first;
  double fontSize = 18;
  double lineHeight = 1.8;
  double margin = 16;
  DirectionMode directionMode = DirectionMode.auto;

  /// Minimum Arabic word share (0–50%) for a block to become RTL.
  double threshold = 50;

  DirectionResolver get resolver =>
      DirectionResolver(mode: directionMode, threshold: threshold);

  void _load() {
    final t = _prefs.getString('theme');
    if (t != null && themes.contains(t)) theme = t;
    final f = _prefs.getString('font');
    if (f != null && fonts.contains(f)) font = f;
    fontSize = _prefs.getDouble('fontSize') ?? fontSize;
    lineHeight = _prefs.getDouble('lineHeight') ?? lineHeight;
    margin = _prefs.getDouble('margin') ?? margin;
    threshold = _prefs.getDouble('threshold') ?? threshold;
    final m = _prefs.getString('directionMode');
    directionMode = DirectionMode.values
        .firstWhere((e) => e.name == m, orElse: () => DirectionMode.auto);
  }

  void update(void Function(AppSettings s) change) {
    change(this);
    notifyListeners();
    _prefs.setString('theme', theme);
    _prefs.setString('font', font);
    _prefs.setDouble('fontSize', fontSize);
    _prefs.setDouble('lineHeight', lineHeight);
    _prefs.setDouble('margin', margin);
    _prefs.setDouble('threshold', threshold);
    _prefs.setString('directionMode', directionMode.name);
  }
}
