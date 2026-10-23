import 'package:book_app/data/reading_settings.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String languageName(AppLocalizations l10n, AppLanguage language) =>
    switch (language) {
      AppLanguage.system => l10n.languageSystem,
      AppLanguage.ru => l10n.languageRussian,
      AppLanguage.en => l10n.languageEnglish,
    };

/// The app language from the library: reachable with no books, unlike the
/// reading settings.
Future<void> chooseLanguage(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final settings = ref.read(readingSettingsProvider);
  final chosen = await showModalBottomSheet<AppLanguage>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: RadioGroup<AppLanguage>(
          groupValue: settings.language,
          onChanged: (language) => Navigator.of(context).pop(language),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  l10n.settingsLanguage,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final language in AppLanguage.values)
                RadioListTile<AppLanguage>(
                  value: language,
                  controlAffinity: ListTileControlAffinity.trailing,
                  title: Text(languageName(l10n, language)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  );
  if (chosen == null) return;
  final now = ref.read(readingSettingsProvider);
  if (chosen != now.language) {
    ref
        .read(readingSettingsProvider.notifier)
        .set(now.copyWith(language: chosen));
  }
}
