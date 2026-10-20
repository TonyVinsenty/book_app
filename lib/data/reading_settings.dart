import 'dart:async';

import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/app/theme/page_texture.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/data/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Side margins of the page.
enum PageMargins {
  narrow(16),
  normal(24),
  wide(36);

  const PageMargins(this.side);

  /// Left and right margin, logical pixels.
  final double side;
}

/// Alignment of ordinary paragraphs (headings and poems keep their own).
enum BookAlign { left, justify }

/// When the night colors are used.
enum NightMode { system, day, night }

/// How the book text looks (ADR 0003, addendum 2 п. 1). Stored in the
/// settings table, one `reading.*` key per field; a missing or broken value
/// means the default.
@immutable
final class ReadingSettings {
  const ReadingSettings({
    this.font = BookFont.literata,
    this.fontSize,
    this.lineHeight = defaultLineHeight,
    this.margins = PageMargins.normal,
    this.align = BookAlign.left,
    this.palette = ReadingPalette.paper,
    this.night = NightMode.system,
    this.texture = PageTexture.none,
    this.hyphenate = true,
  });

  /// Reads the stored values ([keys] → text), see [toStored].
  factory ReadingSettings.fromStored(Map<String, String> stored) {
    T? byName<T extends Enum>(List<T> values, String key) =>
        values.asNameMap()[stored[key]];
    double? number(String key, double min, double max) {
      final value = double.tryParse(stored[key] ?? '');
      return value != null && value >= min && value <= max ? value : null;
    }

    return ReadingSettings(
      font: byName(BookFont.values, _font) ?? BookFont.literata,
      fontSize: number(_size, fontSizes.first, fontSizes.last),
      lineHeight: number(_lineHeight, 1, 2.5) ?? defaultLineHeight,
      margins: byName(PageMargins.values, _margins) ?? PageMargins.normal,
      align: byName(BookAlign.values, _align) ?? BookAlign.left,
      palette: byName(ReadingPalette.values, _palette) ?? ReadingPalette.paper,
      night: byName(NightMode.values, _night) ?? NightMode.system,
      texture: byName(PageTexture.values, _texture) ?? PageTexture.none,
      hyphenate: stored[_hyphenate] != 'false',
    );
  }

  static const _font = 'reading.font';
  static const _size = 'reading.fontSize';
  static const _lineHeight = 'reading.lineHeight';
  static const _margins = 'reading.margins';
  static const _align = 'reading.align';
  static const _palette = 'reading.palette';
  static const _night = 'reading.night';
  static const _texture = 'reading.texture';
  static const _hyphenate = 'reading.hyphenate';

  /// Prefix of all the keys.
  static const keyPrefix = 'reading.';

  /// A− / A+ steps: by 1 pt up to 20, then by 2 pt.
  static const fontSizes = <double>[
    14, 15, 16, 17, 18, 19, 20, 22, 24, 26, 28, 30, 32, //
  ];
  static const defaultFontSize = 18.0;
  static const defaultLineHeight = 1.45;

  /// Line heights offered in the settings panel: tight, normal, loose.
  static const lineHeights = <double>[1.3, defaultLineHeight, 1.7];

  final BookFont font;

  /// Null until the reader picks a size: then it is [defaultFontSize] times
  /// the system text scale (the system scale is not applied to the book
  /// text itself).
  final double? fontSize;

  /// Line height as a multiple of the font size.
  final double lineHeight;
  final PageMargins margins;
  final BookAlign align;
  final ReadingPalette palette;
  final NightMode night;

  /// Drawn over the page color; does not change the layout.
  final PageTexture texture;

  /// Words of paragraphs break at line ends with «-».
  final bool hyphenate;

  /// The size to lay out with: the chosen one, or the default scaled like
  /// the system text and put on the nearest step.
  double fontSizeFor(TextScaler system) =>
      fontSize ?? _nearestStep(system.scale(defaultFontSize));

  /// One A+ step from [fontSizeFor]; the same settings at the largest size.
  ReadingSettings larger(TextScaler system) {
    final size = fontSizeFor(system);
    return withFontSize(
      fontSizes.firstWhere((s) => s > size, orElse: () => fontSizes.last),
    );
  }

  /// One A− step from [fontSizeFor].
  ReadingSettings smaller(TextScaler system) {
    final size = fontSizeFor(system);
    return withFontSize(
      fontSizes.lastWhere((s) => s < size, orElse: () => fontSizes.first),
    );
  }

  static double _nearestStep(double size) => fontSizes.reduce(
    (best, s) => (s - size).abs() < (best - size).abs() ? s : best,
  );

  ReadingSettings withFontSize(double size) => copyWith(fontSize: size);

  ReadingSettings copyWith({
    BookFont? font,
    double? fontSize,
    double? lineHeight,
    PageMargins? margins,
    BookAlign? align,
    ReadingPalette? palette,
    NightMode? night,
    PageTexture? texture,
    bool? hyphenate,
  }) => ReadingSettings(
    font: font ?? this.font,
    fontSize: fontSize ?? this.fontSize,
    lineHeight: lineHeight ?? this.lineHeight,
    margins: margins ?? this.margins,
    align: align ?? this.align,
    palette: palette ?? this.palette,
    night: night ?? this.night,
    texture: texture ?? this.texture,
    hyphenate: hyphenate ?? this.hyphenate,
  );

  /// Key → text for the settings table; an unset size is left out.
  Map<String, String> toStored() => {
    _font: font.name,
    if (fontSize case final size?) _size: '$size',
    _lineHeight: '$lineHeight',
    _margins: margins.name,
    _align: align.name,
    _palette: palette.name,
    _night: night.name,
    _texture: texture.name,
    _hyphenate: '$hyphenate',
  };

  @override
  bool operator ==(Object other) =>
      other is ReadingSettings &&
      other.font == font &&
      other.fontSize == fontSize &&
      other.lineHeight == lineHeight &&
      other.margins == margins &&
      other.align == align &&
      other.palette == palette &&
      other.night == night &&
      other.texture == texture &&
      other.hyphenate == hyphenate;

  @override
  int get hashCode => Object.hash(
    font,
    fontSize,
    lineHeight,
    margins,
    align,
    palette,
    night,
    texture,
    hyphenate,
  );
}

/// Current reading settings; [ReadingSettingsNotifier.set] shows a change
/// at once and stores it.
final readingSettingsProvider =
    NotifierProvider<ReadingSettingsNotifier, ReadingSettings>(
      ReadingSettingsNotifier.new,
    );

class ReadingSettingsNotifier extends Notifier<ReadingSettings> {
  @override
  ReadingSettings build() => const ReadingSettings();

  /// Reads the stored settings (once, in `main()`).
  Future<void> restore() async {
    state = ReadingSettings.fromStored(
      await ref
          .read(settingsRepositoryProvider)
          .getAll(ReadingSettings.keyPrefix),
    );
  }

  /// Shows [next] at once and stores the fields that changed.
  void set(ReadingSettings next) {
    final before = state.toStored();
    state = next;
    final settings = ref.read(settingsRepositoryProvider);
    for (final MapEntry(:key, :value) in next.toStored().entries) {
      if (before[key] != value) unawaited(settings.set(key, value));
    }
  }
}
