import 'dart:ui';

/// The app's language: the first of the phone's languages the app has,
/// else English (the stores' common language). The phone's region is kept:
/// dates and times in en_GB are not those of en_US.
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    if (supported.any((l) => l.languageCode == locale.languageCode)) {
      return Locale(locale.languageCode, locale.countryCode);
    }
  }
  return supported.firstWhere(
    (l) => l.languageCode == 'en',
    orElse: () => supported.first,
  );
}
