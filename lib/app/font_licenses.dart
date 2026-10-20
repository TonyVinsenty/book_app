import 'package:book_app/layout/hyphenation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _fontLicenses = {
  'Literata': 'assets/fonts/licenses/Literata-OFL.txt',
  'Lora': 'assets/fonts/licenses/Lora-OFL.txt',
  'Manrope': 'assets/fonts/licenses/Manrope-OFL.txt',
  'Noto Serif': 'assets/fonts/licenses/NotoSerif-OFL.txt',
  'PT Serif': 'assets/fonts/licenses/PTSerif-OFL.txt',
};

/// Bundled fonts are under the SIL Open Font License, which must ship with
/// the app; this adds them to the system license page, with the
/// hyphenation patterns (their license is in the file header).
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final MapEntry(key: family, value: path) in _fontLicenses.entries) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(path));
    }
    for (final MapEntry(key: name, value: path)
        in Hyphenation.licenses.entries) {
      final header = (await rootBundle.loadString(path))
          .split('\n')
          .takeWhile((line) => line.startsWith('%'));
      yield LicenseEntryWithLineBreaks([
        name,
      ], header.map((line) => line.substring(1).trimRight()).join('\n'));
    }
  });
}
