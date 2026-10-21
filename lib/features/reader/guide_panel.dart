import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// The leading highlight on a pause, at the bottom of the page (ADR 0004,
/// addendum for stage 10 п. 8): start, the book's end, leaving.
class GuidePanel extends StatelessWidget {
  const GuidePanel({
    super.key,
    required this.insets,
    required this.started,
    required this.newChapter,
    required this.finished,
    required this.onPlay,
    required this.onExit,
  });

  final EdgeInsets insets;

  /// Played at least once: the hint says "continue", not "start".
  final bool started;

  /// Paused by itself before a new chapter.
  final bool newChapter;
  final bool finished;
  final VoidCallback onPlay;
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
          insets.bottom + 12,
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
            ] else ...[
              if (newChapter) ...[
                Text(l10n.speedNewChapter, style: secondary),
                const SizedBox(height: 8),
                FilledButton(onPressed: onPlay, child: Text(l10n.speedStart)),
              ] else
                Text(
                  started ? l10n.speedTapToContinue : l10n.speedTapToStart,
                  style: secondary,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.close),
                label: Text(l10n.guideExit),
                onPressed: onExit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
