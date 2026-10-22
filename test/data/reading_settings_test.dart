import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/app/theme/page_texture.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const defaults = ReadingSettings();
  const noScale = TextScaler.noScaling;

  test('stored values come back', () {
    const settings = ReadingSettings(
      font: BookFont.lora,
      fontSize: 22,
      lineHeight: 1.6,
      margins: PageMargins.wide,
      align: BookAlign.justify,
      palette: ReadingPalette.mist,
      night: NightMode.night,
      texture: PageTexture.twill,
      hyphenate: false,
      showStats: false,
    );
    expect(ReadingSettings.fromStored(settings.toStored()), settings);
    expect(ReadingSettings.fromStored(defaults.toStored()), defaults);
    expect(defaults.toStored().keys, everyElement(startsWith('reading.')));
  });

  test('missing or broken values mean the defaults', () {
    expect(ReadingSettings.fromStored({}), defaults);
    expect(
      ReadingSettings.fromStored({
        'reading.font': 'Comic Sans',
        'reading.fontSize': '400',
        'reading.lineHeight': 'tall',
        'reading.margins': '',
        'reading.align': 'center',
        'reading.palette': 'neon',
        'reading.night': 'NIGHT',
        'reading.texture': 'velvet',
        'reading.hyphenate': 'maybe',
      }),
      defaults,
    );
    expect(
      ReadingSettings.fromStored({'reading.fontSize': '-5'}).fontSize,
      isNull,
    );
  });

  test('the default size follows the system scale, on a step', () {
    expect(defaults.fontSizeFor(noScale), 18);
    expect(defaults.fontSizeFor(const TextScaler.linear(1.3)), 24);
    expect(defaults.fontSizeFor(const TextScaler.linear(0.85)), 15);
    expect(defaults.fontSizeFor(const TextScaler.linear(3)), 32);
    expect(
      const ReadingSettings(fontSize: 16)
          .fontSizeFor(const TextScaler.linear(2)),
      16,
    );
  });

  test('A+ and A− walk the steps and stop at the ends', () {
    var s = defaults;
    final sizes = <double>[];
    for (var i = 0; i < 9; i++) {
      s = s.larger(noScale);
      sizes.add(s.fontSizeFor(noScale));
    }
    expect(sizes, [19, 20, 22, 24, 26, 28, 30, 32, 32]);
    for (var i = 0; i < 14; i++) {
      s = s.smaller(noScale);
    }
    expect(s.fontSize, 14);
    // From a scaled default the first step is from the shown size.
    expect(defaults.larger(const TextScaler.linear(1.3)).fontSize, 26);
  });

  group('notifier', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('a change shows at once, is stored and restored', () async {
      final notifier = container.read(readingSettingsProvider.notifier);
      expect(container.read(readingSettingsProvider), defaults);

      notifier.set(defaults.copyWith(font: BookFont.ptSerif, fontSize: 20));
      expect(container.read(readingSettingsProvider).font, BookFont.ptSerif);
      await pumpEventQueue();

      final repo = SettingsRepository(db);
      expect(await repo.get('reading.font'), 'ptSerif');
      expect(await repo.get('reading.fontSize'), '20.0');

      final other = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(other.dispose);
      await other.read(readingSettingsProvider.notifier).restore();
      expect(
        other.read(readingSettingsProvider),
        defaults.copyWith(font: BookFont.ptSerif, fontSize: 20),
      );
    });
  });
}
