import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// A− or A+: book text one step smaller or larger; off ([onPressed] null)
/// at the end of the scale.
class FontSizeButton extends StatelessWidget {
  const FontSizeButton({
    required this.larger,
    required this.onPressed,
    super.key,
  });

  final bool larger;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Tooltip(
      message: larger ? l10n.readerFontLarger : l10n.readerFontSmaller,
      child: OutlinedButton(
        onPressed: onPressed,
        child: ExcludeSemantics(
          child: Text(
            larger ? l10n.readerFontLargerShort : l10n.readerFontSmallerShort,
          ),
        ),
      ),
    );
  }
}
