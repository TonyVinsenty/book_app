import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/features/speed/speed_controls.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/speed/speed_mode.dart';
import 'package:flutter/material.dart';

/// The leading highlight on a pause, at the bottom of the page (ADR 0004,
/// addendum for stage 10 п. 8): back, start, speed − N +, the mode switch,
/// the reading settings, leaving; the book's end.
class GuidePanel extends StatelessWidget {
  const GuidePanel({
    super.key,
    required this.insets,
    required this.started,
    required this.newChapter,
    required this.finished,
    required this.wpm,
    required this.pro,
    required this.onPlay,
    required this.onBack,
    required this.onSpeed,
    required this.onMode,
    required this.onSettings,
    required this.onExit,
  });

  final EdgeInsets insets;

  /// Played at least once: the hint says "continue", not "start".
  final bool started;

  /// Paused by itself before a new chapter.
  final bool newChapter;
  final bool finished;
  final int wpm;

  /// Without "Pro" there is no mode switch.
  final bool pro;
  final VoidCallback onPlay;

  /// Back by a sentence; null at the book's first word.
  final VoidCallback? onBack;
  final ValueChanged<int> onSpeed;
  final ValueChanged<SpeedMode> onMode;
  final VoidCallback onSettings;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.readingColors;
    final text = Theme.of(context).textTheme;
    final secondary = text.bodyMedium?.copyWith(color: colors.textSecondary);
    return Material(
      color: colors.surface,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          insets.left + 16,
          12,
          insets.right + 16,
          insets.bottom + 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (finished) ...[
              Text(l10n.speedBookEnd, style: text.titleMedium),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onExit,
                child: Text(l10n.speedBackToText),
              ),
              const SizedBox(height: 4),
            ] else ...[
              Text(
                newChapter
                    ? l10n.speedNewChapter
                    : started
                    ? l10n.speedTapToContinue
                    : l10n.speedTapToStart,
                style: secondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      tooltip: l10n.speedBackSentence,
                      onPressed: onBack,
                    ),
                    const SizedBox(width: 4),
                    IconButton.filled(
                      iconSize: 32,
                      icon: const Icon(Icons.play_arrow),
                      tooltip: l10n.speedStart,
                      onPressed: onPlay,
                    ),
                    const SizedBox(width: 12),
                    SpeedStepper(wpm: wpm, onChange: onSpeed),
                  ],
                ),
              ),
              if (pro) ...[
                const SizedBox(height: 12),
                SpeedModeSwitch(mode: SpeedMode.guide, onChanged: onMode),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        icon: const Icon(Icons.close),
                        label: Text(l10n.guideExit),
                        onPressed: onExit,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune),
                    tooltip: l10n.readerSettings,
                    onPressed: onSettings,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
