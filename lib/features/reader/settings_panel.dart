import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The reading settings over the bottom of the page: every change shows at
/// once, the page stays on its word (ADR 0003, addendum 2 п. 4).
class ReadingSettingsPanel extends ConsumerWidget {
  const ReadingSettingsPanel({super.key, required this.insets});

  /// Screen insets the panel keeps clear of.
  final EdgeInsets insets;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final settings = ref.watch(readingSettingsProvider);
    final notifier = ref.read(readingSettingsProvider.notifier);
    final scale = MediaQuery.textScalerOf(context);
    final fontSize = settings.fontSizeFor(scale);
    const sizes = ReadingSettings.fontSizes;
    final night = Theme.of(context).brightness == Brightness.dark;

    Widget section(String title, Widget child) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );

    Widget choices<T>(
      List<T> values,
      T selected,
      String Function(T) label,
      ReadingSettings Function(T) apply,
    ) => SegmentedButton<T>(
      segments: [
        for (final value in values)
          ButtonSegment(value: value, label: Text(label(value))),
      ],
      selected: {if (values.contains(selected)) selected},
      emptySelectionAllowed: true,
      showSelectedIcon: false,
      onSelectionChanged: (picked) {
        if (picked.isNotEmpty) notifier.set(apply(picked.first));
      },
    );

    return Material(
      color: colors.surface,
      elevation: 2,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            insets.left + 16,
            4,
            insets.right + 16,
            insets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              section(
                l10n.settingsFont,
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final font in BookFont.values)
                      ChoiceChip(
                        // The name in its own font.
                        label: Text(
                          font.family,
                          style: TextStyle(fontFamily: font.family),
                        ),
                        selected: settings.font == font,
                        showCheckmark: false,
                        onSelected: (_) =>
                            notifier.set(settings.copyWith(font: font)),
                      ),
                  ],
                ),
              ),
              section(
                l10n.settingsSize,
                Row(
                  children: [
                    Tooltip(
                      message: l10n.readerFontSmaller,
                      child: OutlinedButton(
                        onPressed: fontSize > sizes.first
                            ? () => notifier.set(settings.smaller(scale))
                            : null,
                        child: const ExcludeSemantics(child: Text('A−')),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        fontSize.round().toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Tooltip(
                      message: l10n.readerFontLarger,
                      child: OutlinedButton(
                        onPressed: fontSize < sizes.last
                            ? () => notifier.set(settings.larger(scale))
                            : null,
                        child: const ExcludeSemantics(child: Text('A+')),
                      ),
                    ),
                  ],
                ),
              ),
              section(
                l10n.settingsLineHeight,
                choices(
                  ReadingSettings.lineHeights,
                  settings.lineHeight,
                  (height) =>
                      switch (ReadingSettings.lineHeights.indexOf(height)) {
                        0 => l10n.lineHeightTight,
                        1 => l10n.lineHeightNormal,
                        _ => l10n.lineHeightLoose,
                      },
                  (height) => settings.copyWith(lineHeight: height),
                ),
              ),
              section(
                l10n.settingsMargins,
                choices(
                  PageMargins.values,
                  settings.margins,
                  (margins) => switch (margins) {
                    PageMargins.narrow => l10n.marginsNarrow,
                    PageMargins.normal => l10n.marginsNormal,
                    PageMargins.wide => l10n.marginsWide,
                  },
                  (margins) => settings.copyWith(margins: margins),
                ),
              ),
              section(
                l10n.settingsAlign,
                choices(
                  BookAlign.values,
                  settings.align,
                  (align) => switch (align) {
                    BookAlign.left => l10n.alignLeft,
                    BookAlign.justify => l10n.alignJustify,
                  },
                  (align) => settings.copyWith(align: align),
                ),
              ),
              section(
                l10n.settingsPalette,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final palette in ReadingPalette.values)
                      _PaletteSwatch(
                        colors: palette.colors(night: night),
                        label: switch (palette) {
                          ReadingPalette.paper => l10n.palettePaper,
                          ReadingPalette.sage => l10n.paletteSage,
                          ReadingPalette.lavender => l10n.paletteLavender,
                          ReadingPalette.mist => l10n.paletteMist,
                        },
                        selected: settings.palette == palette,
                        onTap: () =>
                            notifier.set(settings.copyWith(palette: palette)),
                      ),
                  ],
                ),
              ),
              section(
                l10n.settingsNight,
                choices(
                  NightMode.values,
                  settings.night,
                  (mode) => switch (mode) {
                    NightMode.system => l10n.nightSystem,
                    NightMode.day => l10n.nightDay,
                    NightMode.night => l10n.nightNight,
                  },
                  (mode) => settings.copyWith(night: mode),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A circle of the palette's page color with «Аа» in its text color.
class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({
    required this.colors,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ReadingColors colors;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = context.readingColors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? current.accent : current.textSecondary,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: Text('Аа', style: TextStyle(color: colors.text)),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? current.text : current.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
