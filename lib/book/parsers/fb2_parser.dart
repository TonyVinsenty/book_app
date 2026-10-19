/// FictionBook 2 books (ADR 0002): sections, titles, paragraphs, poems,
/// epigraphs and citations, bold and italic, the cover. Read as a stream of
/// XML events, so 10 MB files with pictures stay cheap; a broken tail keeps
/// the text read before it. Other pictures and footnotes are skipped for now.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:book_app/book/encoding/text_decoder.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/book_cover.dart';
import 'package:book_app/book/parsers/parse_utils.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

/// Bump when the result for the same file changes (books get re-parsed).
const fb2ParserVersion = 2;

/// The file is not FictionBook (no `<FictionBook>` root).
final class NotFb2Exception implements Exception {
  const NotFb2Exception();

  @override
  String toString() => 'NotFb2Exception';
}

/// [title] is used when the file has no `book-title` (usually the file name).
/// Throws [NotFb2Exception] or [NotTextException].
BookContent parseFb2(
  Uint8List bytes, {
  required String title,
  SourceFormat format = SourceFormat.fb2,
}) => parseFb2WithCover(bytes, title: title, format: format).$1;

/// [parseFb2] plus the `coverpage` picture, if the file has a usable one.
(BookContent, BookCover?) parseFb2WithCover(
  Uint8List bytes, {
  required String title,
  SourceFormat format = SourceFormat.fb2,
}) => _parse(
  decodeText(bytes, declared: _declaredEncoding(bytes)).text,
  title: title,
  format: format,
);

BookContent parseFb2String(
  String xml, {
  required String title,
  SourceFormat format = SourceFormat.fb2,
}) => _parse(xml, title: title, format: format).$1;

(BookContent, BookCover?) _parse(
  String xml, {
  required String title,
  required SourceFormat format,
}) {
  final start = xml.indexOf('<');
  if (start < 0) throw const NotFb2Exception();
  final reader = _Reader();
  try {
    for (final event in parseEvents(
      xml.substring(start),
      entityMapping: const XmlDefaultEntityMapping.html5(),
    )) {
      if (!reader.handle(event)) throw const NotFb2Exception();
    }
  } on XmlException {
    // A broken file: keep what was read before the error.
    if (!reader.hasText) throw const NotFb2Exception();
  }
  if (!reader.isFictionBook) throw const NotFb2Exception();
  return (reader.finish(fallbackTitle: title, format: format), reader.cover());
}

/// Base64 of a picture bigger than [maxCoverBytes] is not collected.
const _maxCoverText = maxCoverBytes * 4 ~/ 3 + 64 * 1024;

final _encodingAttribute = RegExp(r'''encoding\s*=\s*["']([^"']+)["']''');

/// `encoding=` of the XML declaration at the start of the file.
TextEncoding? _declaredEncoding(Uint8List bytes) {
  final head = latin1.decode(
    Uint8List.sublistView(bytes, 0, bytes.length < 200 ? bytes.length : 200),
  );
  final end = head.indexOf('?>');
  if (!head.trimLeft().startsWith('<?xml') || end < 0) return null;
  final match = _encodingAttribute.firstMatch(head.substring(0, end));
  return match == null ? null : encodingByName(match[1]!);
}

const _inline = {
  'strong',
  'emphasis',
  'style',
  'a',
  'strikethrough',
  'sub',
  'sup',
  'code',
  'image',
};

/// Bodies with footnotes and comments, not the main text.
const _noteBodies = {'notes', 'comments', 'footnotes'};

enum _Kind { paragraph, stanza, sectionTitle, bodyTitle, annotation }

/// A text block being collected: whitespace runs become one space, soft
/// hyphens are dropped, lines (title parts, verses) are joined with `\n`.
final class _Text {
  _Text(this.kind, this.style, this.owner);

  final _Kind kind;
  final ParagraphStyle style;

  /// Depth of the element whose end finishes the block.
  final int owner;

  final _buffer = StringBuffer();
  final spans = <Span>[];
  final _open = <(int, SpanKind)>[];
  var _space = false;
  var _lineStart = true;

  bool get isEmpty => _buffer.isEmpty;

  void add(String s) {
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        if (!_lineStart) _space = true;
      } else if (c != 0xAD) {
        if (_space) _buffer.writeCharCode(0x20);
        _buffer.writeCharCode(c);
        _space = false;
        _lineStart = false;
      }
    }
  }

  void lineBreak() {
    if (_lineStart) return;
    _buffer.writeCharCode(0x0A);
    _space = false;
    _lineStart = true;
  }

  /// A word gap without text (between table cells).
  void gap() {
    if (!_lineStart) _space = true;
  }

  void openSpan(SpanKind kind) =>
      _open.add((_buffer.length + (_space ? 1 : 0), kind));

  void closeSpan(SpanKind kind) {
    final i = _open.lastIndexWhere((s) => s.$2 == kind);
    if (i < 0) return;
    final (start, _) = _open.removeAt(i);
    if (start < _buffer.length) spans.add(Span(start, _buffer.length, kind));
  }

  /// The text without a trailing line break; null when empty.
  String? finish() {
    while (_open.isNotEmpty) {
      closeSpan(_open.last.$2);
    }
    var text = _buffer.toString();
    if (text.endsWith('\n')) text = text.substring(0, text.length - 1);
    spans.sort((a, b) => a.start - b.start);
    return text.isEmpty ? null : text;
  }
}

final class _Reader {
  final _stack = <String>[];
  bool isFictionBook = false;
  bool hasText = false;

  /// Everything inside the element at this depth is ignored.
  int? _skip;

  // description/title-info
  String? _bookTitle;
  final _authors = <String>[];
  Map<String, String>? _author;
  StringBuffer? _field;
  String? _series;
  int? _seriesNumber;
  String? _lang;
  String? _annotation;

  /// The `binary` id the `coverpage` points to, and its base64 text.
  String? _coverId;
  StringBuffer? _coverText;
  var _coverDone = false;

  // the main body
  var _inBody = false;
  var _sectionDepth = 0;
  final _sections = <Section>[];
  final _toc = <TocEntry>[];
  var _blocks = <Block>[];
  String? _sectionTitle;
  _Text? _text;

  /// False when the root is not `FictionBook`.
  bool handle(XmlEvent event) {
    switch (event) {
      case XmlStartElementEvent():
        if (_stack.isEmpty && !isFictionBook) {
          if (event.localName != 'FictionBook') return false;
          isFictionBook = true;
        }
        _stack.add(event.localName);
        if (_skip == null) _start(event.localName, event.attributes);
        if (event.isSelfClosing) _pop();
      case XmlEndElementEvent():
        final name = _localName(event.name);
        // Unclosed tags inside are closed together with this one.
        if (_stack.lastIndexOf(name) < 0) break;
        while (_stack.last != name) {
          _pop();
        }
        _pop();
      case XmlTextEvent(:final value) || XmlCDATAEvent(:final value):
        if (_skip == null) {
          _addText(value);
        } else if (_coverText case final cover? when !_coverDone) {
          cover.write(value);
          if (cover.length > _maxCoverText) _coverText = null;
        }
      default:
        break;
    }
    return true;
  }

  static String _localName(String name) {
    final colon = name.indexOf(':');
    return colon < 0 ? name : name.substring(colon + 1);
  }

  String? get _parent => _stack.length >= 2 ? _stack[_stack.length - 2] : null;

  bool get _inTitleInfo =>
      _stack.length >= 3 &&
      _stack[1] == 'description' &&
      _stack[2] == 'title-info';

  void _pop() {
    final depth = _stack.length;
    final name = _stack.removeLast();
    if (_skip != null) {
      if (depth == _skip) {
        _skip = null;
        if (_coverText != null) _coverDone = true;
      }
      return;
    }
    _end(name, depth);
  }

  void _start(String name, List<XmlEventAttribute> attributes) {
    final depth = _stack.length;
    String? attribute(String local) {
      for (final a in attributes) {
        if (a.localName == local) return a.value;
      }
      return null;
    }

    if (name == 'binary') {
      _skip = depth;
      final id = attribute('id');
      if (id != null && id == _coverId && _coverText == null && !_coverDone) {
        _coverText = StringBuffer();
      }
      return;
    }
    if (_inTitleInfo) {
      _startTitleInfo(name, depth, attribute);
      return;
    }
    if (name == 'body' && depth == 2) {
      final bodyName = attribute('name')?.trim().toLowerCase();
      if (_noteBodies.contains(bodyName)) {
        _skip = depth;
      } else {
        _inBody = true;
      }
      return;
    }
    if (!_inBody) return;

    switch (name) {
      case 'section':
        _flushText();
        _sectionDepth++;
        _closeSectionIfContent();
      case 'title':
        _flushText();
        final parent = _parent;
        _text = parent == 'poem' || parent == 'stanza'
            ? _Text(_Kind.paragraph, ParagraphStyle.subtitle, depth)
            : _Text(
                parent == 'section' ? _Kind.sectionTitle : _Kind.bodyTitle,
                ParagraphStyle.normal,
                depth,
              );
      // A title of several lines (`Глава 1` / `Начало`).
      case 'p' when _parent == 'title' && _text != null:
        _text!.lineBreak();
      case 'v':
        if (_text?.kind == _Kind.stanza) {
          _text!.lineBreak();
        } else {
          _flushText();
          final owner = _parent == 'stanza' ? depth - 1 : depth;
          _text = _Text(_Kind.stanza, _style(), owner);
        }
      case 'subtitle':
        _flushText();
        _text = _Text(_Kind.paragraph, ParagraphStyle.subtitle, depth);
      case 'p' || 'text-author' || 'date' || 'tr':
        _flushText();
        _text = _Text(_Kind.paragraph, _style(), depth);
      case 'td' || 'th':
        _text?.gap();
      case 'strong' || 'emphasis':
        _implicitText(depth - 1).openSpan(_spanKind(name));
      case 'a':
        // A footnote mark like `[1]`: not a word of the text.
        final href = attribute('href');
        if (attribute('type') == 'note' || (href?.startsWith('#') ?? false)) {
          _skip = depth;
        }
      case 'empty-line':
        break;
      default:
        if (!_inline.contains(name)) _flushText();
    }
  }

  void _startTitleInfo(
    String name,
    int depth,
    String? Function(String) attribute,
  ) {
    switch (name) {
      case 'author' when depth == 4:
        _author = {};
      case 'book-title' ||
          'lang' ||
          'first-name' ||
          'middle-name' ||
          'last-name' ||
          'nickname':
        _field = StringBuffer();
      case 'sequence' when _series == null:
        _series = attribute('name')?.trim();
        if (_series?.isEmpty ?? false) _series = null;
        _seriesNumber = int.tryParse(attribute('number')?.trim() ?? '');
      case 'annotation' when depth == 4:
        _text = _Text(_Kind.annotation, ParagraphStyle.normal, depth);
      case 'image' when _parent == 'coverpage' && _coverId == null:
        final href = attribute('href')?.trim() ?? '';
        final id = href.startsWith('#') ? href.substring(1) : href;
        if (id.isNotEmpty) _coverId = id;
      case 'p' when _text?.kind == _Kind.annotation:
        _text!.lineBreak();
    }
  }

  void _end(String name, int depth) {
    // The block ends with its owner or anything around it, not with a verse
    // of a stanza or a line of a title.
    if (_text case final text? when text.owner >= depth) _flushText();
    if (_inTitleInfo || (name == 'title-info' && depth == 3)) {
      _endTitleInfo(name, depth);
      return;
    }
    if (!_inBody) return;
    switch (name) {
      case 'strong' || 'emphasis':
        _text?.closeSpan(_spanKind(name));
      case 'section':
        _sectionDepth--;
      case 'body' when depth == 2:
        _closeSection();
        _inBody = false;
    }
  }

  void _endTitleInfo(String name, int depth) {
    final field = _field == null ? null : cleanSpaces(_field.toString());
    if (field != null) _field = null;
    switch (name) {
      case 'book-title' when field != null && field.isNotEmpty:
        _bookTitle ??= field;
      case 'lang' when field != null && field.isNotEmpty:
        _lang ??= field.toLowerCase();
      case 'first-name' || 'middle-name' || 'last-name' || 'nickname'
          when field != null && field.isNotEmpty:
        _author?[name] = field;
      case 'author' when depth == 4:
        final parts = _author ?? const {};
        final full = [
          ?parts['first-name'],
          ?parts['middle-name'],
          ?parts['last-name'],
        ].join(' ');
        final author = full.isNotEmpty ? full : parts['nickname'];
        if (author != null) _authors.add(author);
        _author = null;
    }
  }

  void _addText(String value) {
    if (_field case final field?) {
      field.write(value);
      return;
    }
    if (_text case final text?) {
      text.add(value);
      return;
    }
    // Text right inside a section (broken files): an unmarked paragraph.
    if (_inBody && value.trim().isNotEmpty) {
      _implicitText(_stack.length).add(value);
    }
  }

  _Text _implicitText(int owner) =>
      _text ??= _Text(_Kind.paragraph, _style(), owner);

  /// The look of a paragraph from the elements around it: an epigraph wins
  /// (a poem in an epigraph is still an epigraph), then the nearest poem or
  /// citation.
  ParagraphStyle _style() {
    if (_stack.contains('epigraph')) return ParagraphStyle.epigraph;
    for (var i = _stack.length - 1; i >= 0; i--) {
      switch (_stack[i]) {
        case 'poem':
          return ParagraphStyle.poem;
        case 'cite' || 'annotation':
          return ParagraphStyle.quote;
        case 'section' || 'body':
          return ParagraphStyle.normal;
      }
    }
    return ParagraphStyle.normal;
  }

  static SpanKind _spanKind(String name) =>
      name == 'strong' ? SpanKind.strong : SpanKind.emphasis;

  void _flushText() {
    final text = _text;
    if (text == null) return;
    _text = null;
    final value = text.finish();
    if (value == null) return;
    switch (text.kind) {
      case _Kind.annotation:
        _annotation ??= value;
        return;
      // `<subtitle>* * *</subtitle>`: a scene break.
      case _Kind.paragraph when separatorPattern.hasMatch(value):
        _blocks.add(const SeparatorBlock());
      case _Kind.paragraph || _Kind.stanza:
        _blocks.add(
          ParagraphBlock(text: value, style: text.style, spans: text.spans),
        );
      case _Kind.bodyTitle:
        _blocks.add(HeadingBlock(text: value, spans: text.spans));
      case _Kind.sectionTitle:
        final level = _sectionDepth < 1 ? 1 : _sectionDepth;
        _blocks.add(HeadingBlock(text: value, level: level, spans: text.spans));
        final title = tocTitle(value);
        _toc.add(
          TocEntry(
            title: title,
            level: level - 1,
            sectionIndex: _sections.length,
          ),
        );
        _sectionTitle ??= title;
    }
    hasText = true;
  }

  /// `Часть I` + `Глава 1` with nothing between share one section.
  void _closeSectionIfContent() {
    if (_blocks.any((b) => b is! HeadingBlock)) _closeSection();
  }

  void _closeSection() {
    if (_blocks.isNotEmpty) {
      _sections.add(Section(title: _sectionTitle, blocks: _blocks));
    }
    _blocks = <Block>[];
    _sectionTitle = null;
  }

  /// The cover picture: only a fully read `binary` that decodes.
  BookCover? cover() {
    final text = _coverText;
    if (!_coverDone || text == null) return null;
    try {
      return coverFromBytes(
        base64.decode(
          base64.normalize(text.toString().replaceAll(whitespacePattern, '')),
        ),
      );
    } on FormatException {
      return null;
    }
  }

  BookContent finish({
    required String fallbackTitle,
    required SourceFormat format,
  }) {
    _flushText();
    _closeSection();
    return BookContent(
      meta: BookMeta(
        title: _bookTitle ?? fallbackTitle,
        authors: _authors,
        series: _series,
        seriesNumber: _seriesNumber,
        lang: _lang,
        annotation: _annotation,
        sourceFormat: format,
      ),
      toc: _toc,
      sections: _sections,
    );
  }
}
