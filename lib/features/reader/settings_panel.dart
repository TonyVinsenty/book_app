import 'package:book_app/app/theme/app_fonts.dart';
import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/page_texture.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/features/reader/font_size_button.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The reading settings over the bottom of the page: every change shows at
/// once, the page stays on its word (ADR 0003, addendum 2 п. 4). A swipe
/// down closes it, as a tap on the page does.
class ReadingSettingsPanel extends ConsumerWidget {
  const ReadingSettingsPanel({
    super.key,
    required this.insets,
    required this.onClose,
  });

  /// Screen insets the panel keeps clear of.
  final EdgeInsets insets;

  final VoidCallback onClose;

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

    return _SwipeDownToClose(
      onClose: onClose,
      // Rounded on top like the other sheets (14.2, A13).
      child: Material(
        color: colors.surface,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The grip: something to pull down.
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  // Clamping on every platform: pulling down at the top overscrolls,
                  // which moves the panel.
                  physics: const ClampingScrollPhysics(),
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
                            FontSizeButton(
                              larger: false,
                              onPressed: fontSize > sizes.first
                                  ? () => notifier.set(settings.smaller(scale))
                                  : null,
                            ),
                            Expanded(
                              child: Text(
                                fontSize.round().toString(),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            FontSizeButton(
                              larger: true,
                              onPressed: fontSize < sizes.last
                                  ? () => notifier.set(settings.larger(scale))
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      section(
                        l10n.settingsLineHeight,
                        choices(
                          ReadingSettings.lineHeights,
                          settings.lineHeight,
                          (height) => switch (ReadingSettings.lineHeights
                              .indexOf(height)) {
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
                        l10n.settingsHyphenation,
                        choices(
                          const [false, true],
                          settings.hyphenate,
                          (on) => on ? l10n.hyphenationOn : l10n.hyphenationOff,
                          (on) => settings.copyWith(hyphenate: on),
                        ),
                      ),
                      section(
                        l10n.settingsVerticalScroll,
                        choices(
                          const [false, true],
                          settings.verticalScroll,
                          (on) => on
                              ? l10n.verticalScrollOn
                              : l10n.verticalScrollOff,
                          (on) => settings.copyWith(verticalScroll: on),
                        ),
                      ),
                      section(
                        l10n.settingsShowStats,
                        choices(
                          const [false, true],
                          settings.showStats,
                          (on) => on ? l10n.showStatsOn : l10n.showStatsOff,
                          (on) => settings.copyWith(showStats: on),
                        ),
                      ),
                      section(
                        l10n.settingsPalette,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            for (final palette in ReadingPalette.values)
                              _Swatch(
                                decoration: BoxDecoration(
                                  color: palette
                                      .colors(night: night)
                                      .background,
                                  shape: BoxShape.circle,
                                ),
                                content: Text(
                                  l10n.settingsPaletteSample,
                                  style: TextStyle(
                                    color: palette.colors(night: night).text,
                                  ),
                                ),
                                label: switch (palette) {
                                  ReadingPalette.paper => l10n.palettePaper,
                                  ReadingPalette.sage => l10n.paletteSage,
                                  ReadingPalette.lavender =>
                                    l10n.paletteLavender,
                                  ReadingPalette.mist => l10n.paletteMist,
                                },
                                selected: settings.palette == palette,
                                onTap: () => notifier.set(
                                  settings.copyWith(palette: palette),
                                ),
                              ),
                          ],
                        ),
                      ),
                      section(
                        l10n.settingsTexture,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            for (final texture in PageTexture.values)
                              _Swatch(
                                decoration: BoxDecoration(
                                  color: colors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                content: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: TextureSample(texture: texture),
                                ),
                                label: switch (texture) {
                                  PageTexture.none => l10n.textureNone,
                                  PageTexture.paper => l10n.texturePaper,
                                  PageTexture.twill => l10n.textureTwill,
                                  PageTexture.scales => l10n.textureScales,
                                  PageTexture.mattress => l10n.textureMattress,
                                },
                                selected: settings.texture == texture,
                                onTap: () => notifier.set(
                                  settings.copyWith(texture: texture),
                                ),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// Follows a finger pulling [child] down, by its grip or past the top of its
/// list, and calls [onClose] once it is pulled far or fast enough.
class _SwipeDownToClose extends StatefulWidget {
  const _SwipeDownToClose({required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  State<_SwipeDownToClose> createState() => _SwipeDownToCloseState();
}

class _SwipeDownToCloseState extends State<_SwipeDownToClose> {
  double _offset = 0;
  bool _dragging = false;

  static const _closeDistance = 64.0;
  static const _closeVelocity = 700.0;

  void _drag(double dy) => setState(() {
    _dragging = true;
    _offset = (_offset + dy).clamp(0, double.infinity);
  });

  void _release(double velocity) {
    if (!_dragging) return;
    if (_offset > _closeDistance || velocity > _closeVelocity) {
      widget.onClose();
    }
    setState(() {
      _dragging = false;
      _offset = 0;
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n is OverscrollNotification && n.dragDetails != null) {
      if (n.overscroll < 0) _drag(-n.overscroll);
    } else if (n is ScrollUpdateNotification && _dragging) {
      // Pulled down, then back up: the panel goes up first.
      final dy = n.dragDetails?.delta.dy ?? 0;
      if (dy < 0) _drag(dy);
    } else if (n is ScrollEndNotification) {
      _release(n.dragDetails?.primaryVelocity ?? 0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onVerticalDragUpdate: (d) => _drag(d.delta.dy),
    onVerticalDragEnd: (d) => _release(d.primaryVelocity ?? 0),
    child: NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: AnimatedContainer(
        duration: _dragging ? Duration.zero : const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _offset, 0),
        child: widget.child,
      ),
    ),
  );
}

/// A sample of a page look (a palette's circle with «Аа», a texture's
/// square) with its name under it.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.decoration,
    this.content,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// The sample; its border shows the selection.
  final BoxDecoration decoration;
  final Widget? content;
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
                decoration: decoration.copyWith(
                  border: Border.all(
                    color: selected ? current.accent : current.textSecondary,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: content,
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
