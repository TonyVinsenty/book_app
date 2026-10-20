/// The single in-memory book model every format is converted to on import
/// (ADR 0002). Pure Dart: runs in isolates and is stored as
/// `content.v<N>.json.gz`.
library;

/// Source file format of a book.
enum SourceFormat { txt, fb2, fb2zip, epub }

/// Book metadata taken from the file.
final class BookMeta {
  const BookMeta({
    required this.title,
    this.authors = const [],
    this.series,
    this.seriesNumber,
    this.lang,
    this.annotation,
    this.coverAssetId,
    required this.sourceFormat,
  });

  factory BookMeta.fromJson(Map<String, Object?> json) => BookMeta(
    title: json['title']! as String,
    authors: [for (final a in json['authors']! as List<Object?>) a! as String],
    series: json['series'] as String?,
    seriesNumber: json['seriesNumber'] as int?,
    lang: json['lang'] as String?,
    annotation: json['annotation'] as String?,
    coverAssetId: json['coverAssetId'] as String?,
    sourceFormat: SourceFormat.values.byName(json['sourceFormat']! as String),
  );

  final String title;
  final List<String> authors;
  final String? series;
  final int? seriesNumber;

  /// Language code from the file (`ru`, `en`), if known.
  final String? lang;
  final String? annotation;
  final String? coverAssetId;
  final SourceFormat sourceFormat;

  Map<String, Object?> toJson() => {
    'title': title,
    'authors': authors,
    if (series != null) 'series': series,
    if (seriesNumber != null) 'seriesNumber': seriesNumber,
    if (lang != null) 'lang': lang,
    if (annotation != null) 'annotation': annotation,
    if (coverAssetId != null) 'coverAssetId': coverAssetId,
    'sourceFormat': sourceFormat.name,
  };
}

/// Table of contents entry pointing to a section.
final class TocEntry {
  const TocEntry({
    required this.title,
    required this.level,
    required this.sectionIndex,
  });

  factory TocEntry.fromJson(Map<String, Object?> json) => TocEntry(
    title: json['title']! as String,
    level: json['level']! as int,
    sectionIndex: json['section']! as int,
  );

  final String title;

  /// Nesting depth, 0 for top-level entries.
  final int level;
  final int sectionIndex;

  Map<String, Object?> toJson() => {
    'title': title,
    'level': level,
    'section': sectionIndex,
  };
}

/// A chapter: FB2 section, EPUB spine file or a TXT chapter; or a part of
/// a very long one (`splitLongSections`).
final class Section {
  const Section({
    this.title,
    required this.blocks,
    this.continued = false,
    this.firstBlock = 0,
  });

  factory Section.fromJson(Map<String, Object?> json) => Section(
    title: json['title'] as String?,
    blocks: [
      for (final b in json['blocks']! as List<Object?>)
        Block.fromJson(b! as Map<String, Object?>),
    ],
  );

  final String? title;
  final List<Block> blocks;

  /// A part after the first of a long chapter: no new chapter starts here.
  /// Parts are made when a book is opened and never stored.
  final bool continued;

  /// Index of [blocks]' first block in the whole chapter.
  final int firstBlock;

  Map<String, Object?> toJson() => {
    if (title != null) 'title': title,
    'blocks': [for (final b in blocks) b.toJson()],
  };
}

/// Kind of inline markup.
enum SpanKind { emphasis, strong, noteRef }

/// Inline markup over `text[start, end)` of a text block.
final class Span {
  const Span(this.start, this.end, this.kind, {this.noteId})
    : assert(start <= end),
      assert(kind != SpanKind.noteRef || noteId != null);

  factory Span.fromJson(List<Object?> json) => Span(
    json[0]! as int,
    json[1]! as int,
    SpanKind.values.byName(json[2]! as String),
    noteId: json.length > 3 ? json[3] as String? : null,
  );

  final int start;
  final int end;
  final SpanKind kind;

  /// Target note for [SpanKind.noteRef].
  final String? noteId;

  List<Object?> toJson() => [start, end, kind.name, ?noteId];
}

/// Look of a paragraph.
enum ParagraphStyle { normal, epigraph, poem, quote, subtitle, note }

/// A unit of a section. Text blocks ([HeadingBlock], [ParagraphBlock]) carry
/// words; the others are skipped by the tokenizer.
sealed class Block {
  const Block();

  factory Block.fromJson(Map<String, Object?> json) {
    List<Span> spans() => [
      for (final s in (json['spans'] as List<Object?>?) ?? const <Object?>[])
        Span.fromJson(s! as List<Object?>),
    ];
    return switch (json['type']) {
      'heading' => HeadingBlock(
        text: json['text']! as String,
        level: json['level']! as int,
        spans: spans(),
      ),
      'paragraph' => ParagraphBlock(
        text: json['text']! as String,
        style: ParagraphStyle.values.byName(json['style']! as String),
        spans: spans(),
      ),
      'image' => ImageBlock(
        assetId: json['assetId']! as String,
        width: json['width'] as int?,
        height: json['height'] as int?,
      ),
      'separator' => const SeparatorBlock(),
      final type => throw FormatException('Unknown block type: $type'),
    };
  }

  Map<String, Object?> toJson();
}

/// A block with text and inline markup.
sealed class TextBlock extends Block {
  const TextBlock({required this.text, this.spans = const []});

  final String text;
  final List<Span> spans;

  List<List<Object?>>? get _spansJson =>
      spans.isEmpty ? null : [for (final s in spans) s.toJson()];
}

final class HeadingBlock extends TextBlock {
  const HeadingBlock({required super.text, this.level = 1, super.spans});

  /// 1 for chapter titles, larger for nested ones.
  final int level;

  @override
  Map<String, Object?> toJson() => {
    'type': 'heading',
    'text': text,
    'level': level,
    'spans': ?_spansJson,
  };
}

final class ParagraphBlock extends TextBlock {
  const ParagraphBlock({
    required super.text,
    this.style = ParagraphStyle.normal,
    super.spans,
  });

  final ParagraphStyle style;

  @override
  Map<String, Object?> toJson() => {
    'type': 'paragraph',
    'text': text,
    'style': style.name,
    'spans': ?_spansJson,
  };
}

final class ImageBlock extends Block {
  const ImageBlock({required this.assetId, this.width, this.height});

  final String assetId;
  final int? width;
  final int? height;

  @override
  Map<String, Object?> toJson() => {
    'type': 'image',
    'assetId': assetId,
    'width': ?width,
    'height': ?height,
  };
}

final class SeparatorBlock extends Block {
  const SeparatorBlock();

  @override
  Map<String, Object?> toJson() => {'type': 'separator'};
}

/// A whole parsed book.
final class BookContent {
  const BookContent({
    required this.meta,
    this.toc = const [],
    required this.sections,
  });

  factory BookContent.fromJson(Map<String, Object?> json) => BookContent(
    meta: BookMeta.fromJson(json['meta']! as Map<String, Object?>),
    toc: [
      for (final t in json['toc']! as List<Object?>)
        TocEntry.fromJson(t! as Map<String, Object?>),
    ],
    sections: [
      for (final s in json['sections']! as List<Object?>)
        Section.fromJson(s! as Map<String, Object?>),
    ],
  );

  final BookMeta meta;
  final List<TocEntry> toc;
  final List<Section> sections;

  Map<String, Object?> toJson() => {
    'meta': meta.toJson(),
    'toc': [for (final t in toc) t.toJson()],
    'sections': [for (final s in sections) s.toJson()],
  };
}
