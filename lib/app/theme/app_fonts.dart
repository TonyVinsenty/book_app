/// Font families bundled in assets/fonts (declared in pubspec.yaml).
abstract final class AppFonts {
  /// Interface font: menus, panels, settings.
  static const ui = 'Manrope';
}

/// Fonts offered for book text. [family] must match pubspec.yaml.
enum BookFont {
  literata('Literata'),
  ptSerif('PT Serif'),
  lora('Lora'),
  notoSerif('Noto Serif');

  const BookFont(this.family);

  final String family;
}
