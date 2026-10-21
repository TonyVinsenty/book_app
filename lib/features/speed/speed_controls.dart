import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/speed/timing.dart';
import 'package:flutter/material.dart';

/// Speed − N + on a pause, the same in every mode.
class SpeedStepper extends StatelessWidget {
  const SpeedStepper({super.key, required this.wpm, required this.onChange});

  final int wpm;

  /// Gets the change, ±[SpeedLimits.step].
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          icon: const Icon(Icons.remove),
          tooltip: l10n.speedSlower,
          onPressed: wpm > SpeedLimits.min
              ? () => onChange(-SpeedLimits.step)
              : null,
        ),
        SizedBox(
          width: 120,
          child: Text(
            l10n.speedWordsPerMinute(wpm),
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        IconButton.outlined(
          icon: const Icon(Icons.add),
          tooltip: l10n.speedFaster,
          onPressed: wpm < SpeedLimits.max
              ? () => onChange(SpeedLimits.step)
              : null,
        ),
      ],
    );
  }
}

/// "Слово · Фраза · Подсветка" on a pause (ADR 0004, addendum for stage 10
/// п. 10).
class SpeedModeSwitch extends StatelessWidget {
  const SpeedModeSwitch({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final SpeedMode mode;
  final ValueChanged<SpeedMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<SpeedMode>(
      segments: [
        for (final mode in SpeedMode.values)
          ButtonSegment(
            value: mode,
            label: Text(switch (mode) {
              SpeedMode.word => l10n.speedModeWord,
              SpeedMode.phrase => l10n.speedModePhrase,
              SpeedMode.guide => l10n.speedModeGuide,
            }),
          ),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged: (picked) => onChanged(picked.first),
    );
  }
}
