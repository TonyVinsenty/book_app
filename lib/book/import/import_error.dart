/// Why an import failed; screens turn it into a message.
library;

/// Why a file was not added; screens turn it into a message.
enum ImportError {
  /// EPUB, PDF, pictures, a ZIP without books… — not readable (yet).
  unsupportedFormat,

  /// Looks like a book but can't be parsed.
  damaged,

  /// The file could not be read or stored.
  unreadable,
}

final class ImportException implements Exception {
  const ImportException(this.error);

  final ImportError error;

  @override
  String toString() => 'ImportException(${error.name})';
}
