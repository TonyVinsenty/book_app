import 'package:book_app/l10n/generated/app_localizations.dart';

/// «0 мин», «< 1 мин», «N мин», «N ч», «N ч M мин», to the nearest minute
/// (ADR 0009 п. 5).
String formatDuration(AppLocalizations l10n, Duration time) {
  if (time <= Duration.zero) return l10n.statsZero;
  if (time < const Duration(minutes: 1)) return l10n.statsUnderMinute;
  final minutes = (time.inSeconds / 60).round();
  final (hours, rest) = (minutes ~/ 60, minutes % 60);
  if (hours == 0) return l10n.statsMinutes(rest);
  if (rest == 0) return l10n.statsHours(hours);
  return l10n.statsHoursMinutes(hours, rest);
}

/// «октябрь» → «Октябрь».
String capitalized(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
