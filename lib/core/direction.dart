import 'package:flutter/widgets.dart';

enum DirectionMode { auto, rtl, ltr }

class WordCount {
  const WordCount(this.arabic, this.latin);

  final int arabic;
  final int latin;

  int get total => arabic + latin;

  /// Share of Arabic words in percent (0–100). Zero when there are no words.
  double get arabicPercent => total == 0 ? 0 : arabic * 100 / total;
}

/// Decides the direction of a block of text from the RTL sensitivity setting.
///
/// A block is RTL when its Arabic word share is at least [threshold] percent.
/// The slider runs from 50 (normal majority rule) down to 0 (any Arabic word
/// makes the block RTL). Blocks with no Arabic words stay LTR, and blocks with
/// no words at all (numbers, symbols) use the fallback direction.
class DirectionResolver {
  const DirectionResolver({required this.mode, required this.threshold});

  final DirectionMode mode;
  final double threshold;

  static final _arabic = RegExp(
      r'[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]');
  static final _latin = RegExp(r'[A-Za-zÀ-ɏ]');
  static final _ignored = RegExp(r'(https?://\S+|www\.\S+|`[^`]*`)');
  static final _space = RegExp(r'\s+');

  /// Counts Arabic and Latin words. URLs and inline code are ignored, and a
  /// token with any Arabic letter counts as Arabic.
  static WordCount count(String text) {
    final cleaned = text.replaceAll(_ignored, ' ');
    var arabic = 0;
    var latin = 0;
    for (final token in cleaned.split(_space)) {
      if (token.isEmpty) continue;
      if (_arabic.hasMatch(token)) {
        arabic++;
      } else if (_latin.hasMatch(token)) {
        latin++;
      }
    }
    return WordCount(arabic, latin);
  }

  TextDirection resolve(String text,
      {TextDirection fallback = TextDirection.rtl}) {
    return switch (mode) {
      DirectionMode.rtl => TextDirection.rtl,
      DirectionMode.ltr => TextDirection.ltr,
      DirectionMode.auto => _auto(text, fallback),
    };
  }

  TextDirection _auto(String text, TextDirection fallback) {
    final c = count(text);
    if (c.total == 0) return fallback;
    if (c.arabic == 0) return TextDirection.ltr;
    return c.arabicPercent >= threshold ? TextDirection.rtl : TextDirection.ltr;
  }
}
