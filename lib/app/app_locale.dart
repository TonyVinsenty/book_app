import 'dart:ui';

/// The app's language: the first of the phone's languages the app has,
/// else English (the stores' common language).
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
  }
  return supported.firstWhere(
    (l) => l.languageCode == 'en',
    orElse: () => supported.first,
  );
}
