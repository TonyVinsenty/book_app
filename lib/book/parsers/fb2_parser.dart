/// FictionBook 2 books (ADR 0002, 0008): sections, titles, paragraphs,
/// poems, epigraphs and citations, bold and italic, pictures (the cover is
/// the first one) and footnotes from the `notes` and `comments` bodies. Read
/// as a stream of XML events; a broken tail keeps the text read before it.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:book_app/book/encoding/text_decoder.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/model/book_cover.dart';
import 'package:book_app/book/model/book_image.dart';
import 'package:book_app/book/parsers/parse_utils.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

/// Bump when the result for the same file changes (books get re-parsed).
const fb2ParserVersion = 3;

/// The file is not FictionBook (no `<FictionBook>` root).
final class NotFb2Exception implements Exception {
  const NotFb2Exception();

  @override
  String toString() => 'NotFb2Exception';
}

/// [title] is used when the file has no `book-title` (usually the file name);
/// pictures of the text go to [images]. Throws [NotFb2Exception] or
/// [NotTextException].
BookContent parseFb2(
  Uint8List bytes, {
  required String title,
  SourceFormat format = SourceFormat.fb2,
  ImageSink? images,
}) => parseFb2WithCover(bytes, title: title, format: format, images: images).$1;

/// [parseFb2] plus the `coverpage` picture, if the file has a usable one.
(BookContent, BookCover?) parseFb2WithCover(
  Uint8List bytes, {
  required String title,
  SourceFormat format = SourceFormat.fb2,
  ImageSink? images,
}) => _parse(
  decodeText(bytes, declared: _declaredEncoding(bytes)).text,
  title: title,
  format: format,
  images: images,
);

BookContent parseFb2String(
  String xml, {
  required String title,
  SourceFormat format = SourceFormat.fb2,
  ImageSink? images,
}) => _parse(xml, title: title, format: format, images: images).$1;

(BookContent, BookCover?) _parse(
  String xml, {
  required String title,
  required SourceFormat format,
  ImageSink? images,
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
  return (
    reader.finish(fallbackTitle: title, format: format, images: images),
    reader.cover(),
  );
}

/// Base64 of a picture bigger than [maxImageBytes] is not collected.
const _maxBinaryText = maxImageBytes * 4 ~/ 3 + 64 * 1024;

/// `[12]`, `{1}`, `(3)`: the label inside.
final _bracketed = RegExp(r'^[\[{(](.*)[\]})]$');

/// A link text that is a footnote label, not words.
final _markText = RegExp(r'^[0-9*†‡§¶#]{1,6}$');

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

enum _Kind { paragraph, stanza, sectionTitle, bodyTitle, annotation, noteTitle }

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

  /// Kinds of the spans not closed yet, outer first.
  List<SpanKind> get openKinds => [for (final (_, kind) in _open) kind];

  /// A footnote label (ADR 0008): its chars are not words.
  void mark(String label, String noteId) {
    if (_space) _buffer.writeCharCode(0x20);
    _space = false;
    _lineStart = false;
    final start = _buffer.length;
    _buffer.write(label);
    spans.add(Span(start, _buffer.length, SpanKind.noteRef, noteId: noteId));
  }

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

  /// The `binary` id the `coverpage` points to.
  String? _coverId;

  // pictures: blocks are `ImageBlock(assetId: <binary id>)` until [finish]
  final _binaries = <String, Uint8List>{};
  var _binaryBytes = 0;
  final _imageIds = <String>{};
  String? _binaryId;
  StringBuffer? _binaryText;
  var _bodiesRead = 0;

  // footnotes
  var _inNotes = false;
  _OpenNote? _note;
  final _notes = <String, Note>{};

  /// A link to `#id` being read: a footnote label or plain words.
  _Link? _link;

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
        } else if (_binaryText case final binary?) {
          binary.write(value);
          if (binary.length > _maxBinaryText) _binaryText = null;
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
        _endBinary();
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
      final id = attribute('id')?.trim();
      // After the text only the pictures it shows are kept.
      if (id != null &&
          !_binaries.containsKey(id) &&
          (_bodiesRead == 0 || _imageIds.contains(id) || id == _coverId) &&
          _binaryBytes < maxBookImageBytes) {
        _binaryId = id;
        _binaryText = StringBuffer();
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
        _inNotes = true;
      } else {
        _inBody = true;
      }
      return;
    }
    if (_inNotes) {
      if (!_startInNotes(name, depth, attribute)) return;
    } else if (!_inBody) {
      return;
    }

    switch (name) {
      case 'section':
        _flushText();
        _sectionDepth++;
        _closeSectionIfContent();
      case 'title':
        _flushText();
        final parent = _parent;
        _text = parent == 'poem' || parent == 'stanza' || _inNotes
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
      case 'a' when _link == null:
        final href = attribute('href')?.trim() ?? '';
        final isNote = attribute('type') == 'note';
        if (isNote || href.startsWith('#')) {
          _implicitText(depth - 1);
          final id = href.startsWith('#') ? href.substring(1) : href;
          _link = _Link(depth, id, isNote: isNote);
        }
      case 'image':
        _image(attribute('href')?.trim() ?? '');
      case 'empty-line':
        break;
      default:
        if (!_inline.contains(name)) _flushText();
    }
  }

  /// Inside a `notes` body: a section with an id is a footnote, everything
  /// outside footnotes is skipped. False when [name] is handled here.
  bool _startInNotes(
    String name,
    int depth,
    String? Function(String) attribute,
  ) {
    if (name == 'section') {
      _flushText();
      final id = attribute('id')?.trim() ?? '';
      if (id.isNotEmpty) {
        _closeNote();
        _note = _OpenNote(id, depth);
      }
      return false;
    }
    final note = _note;
    if (note == null) {
      _skip = depth;
      return false;
    }
    if (name == 'title' && depth == note.depth + 1) {
      _flushText();
      _text = _Text(_Kind.noteTitle, ParagraphStyle.normal, depth);
      return false;
    }
    return true;
  }

  /// `<image l:href="#id">`: a block; inside a paragraph it splits the
  /// paragraph in two. Pictures in titles are skipped.
  void _image(String href) {
    if (!href.startsWith('#') || href.length < 2) return;
    final id = href.substring(1);
    final text = _text;
    if (text != null &&
        (text.kind == _Kind.sectionTitle ||
            text.kind == _Kind.bodyTitle ||
            text.kind == _Kind.noteTitle)) {
      return;
    }
    _imageIds.add(id);
    final open = text?.openKinds ?? const <SpanKind>[];
    _flushText();
    _blocks.add(ImageBlock(assetId: id));
    if (text != null) {
      _text = _Text(text.kind, text.style, text.owner);
      open.forEach(_text!.openSpan);
    }
  }

  /// The end of a link opened by [_link]: a label when the text looks like
  /// one (or the link says it is a note), the words as they are otherwise.
  void _endLink() {
    final link = _link!;
    _link = null;
    final raw = cleanSpaces(link.text.toString());
    final bracketed = _bracketed.firstMatch(raw);
    final inside = bracketed?[1]!.trim() ?? raw;
    final text = _implicitText(_stack.length);
    if (link.isNote) {
      text.mark(inside.isEmpty ? '*' : inside, link.noteId);
    } else if (inside.isNotEmpty &&
        (_markText.hasMatch(inside) ||
            (bracketed != null && inside.length <= 8))) {
      text.mark(inside, link.noteId);
    } else {
      text.add(link.text.toString());
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
    if (!_inBody && !_inNotes) return;
    switch (name) {
      case 'strong' || 'emphasis':
        _text?.closeSpan(_spanKind(name));
      case 'a' when _link?.depth == depth:
        _endLink();
      case 'section' when _inNotes:
        if (_note?.depth == depth) _closeNote();
      case 'section':
        _sectionDepth--;
      case 'body' when depth == 2 && _inNotes:
        _closeNote();
        _inNotes = false;
        _bodiesRead++;
      case 'body' when depth == 2:
        _closeSection();
        _inBody = false;
        _bodiesRead++;
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
    if (_link case final link?) {
      link.text.write(value);
      return;
    }
    if (_text case final text?) {
      text.add(value);
      return;
    }
    // Text right inside a section (broken files): an unmarked paragraph.
    if ((_inBody || _note != null) && value.trim().isNotEmpty) {
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
      case _Kind.noteTitle:
        _note?.label ??= cleanSpaces(withoutMarks(value, text.spans));
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
        final title = tocTitle(withoutMarks(value, text.spans));
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

  void _closeNote() {
    final note = _note;
    if (note == null) return;
    _flushText();
    _note = null;
    final blocks = _blocks;
    _blocks = <Block>[];
    if (blocks.isEmpty) return;
    _notes.putIfAbsent(note.id, () => Note(label: note.label, blocks: blocks));
  }

  /// A fully read `binary` that decodes is kept for [finish].
  void _endBinary() {
    final id = _binaryId;
    final text = _binaryText;
    _binaryId = null;
    _binaryText = null;
    if (id == null || text == null) return;
    try {
      final bytes = base64.decode(
        base64.normalize(text.toString().replaceAll(whitespacePattern, '')),
      );
      if (bytes.isEmpty) return;
      _binaries[id] = bytes;
      _binaryBytes += bytes.length;
    } on FormatException {
      return;
    }
  }

  /// The cover picture for the library.
  BookCover? cover() {
    final bytes = _binaries[_coverId];
    return bytes == null ? null : coverFromBytes(bytes);
  }

  BookContent finish({
    required String fallbackTitle,
    required SourceFormat format,
    ImageSink? images,
  }) {
    _flushText();
    _closeNote();
    _closeSection();
    // Numbered in book order: the cover, the text, the notes.
    final pictures = BookImages(images);
    ImageBlock? picture(String id) => pictures.add(id, () => _binaries[id]);
    final coverId = _coverId;
    final cover = coverId == null ? null : picture(coverId);
    List<Block> resolve(List<Block> blocks) => [
      for (final b in blocks)
        if (b is ImageBlock) ?picture(b.assetId) else b,
    ];

    // A section of pictures only joins the next one (the last one joins the
    // one before): a chapter has words.
    final sections = <Section>[];
    final newIndex = <int>[];
    var carried = <Block>[];
    for (final s in _sections) {
      final blocks = [...carried, ...resolve(s.blocks)];
      newIndex.add(sections.length);
      if (blocks.any((b) => b is TextBlock)) {
        sections.add(Section(title: s.title, blocks: blocks));
        carried = [];
      } else {
        carried = blocks;
      }
    }
    if (carried.isNotEmpty && sections.isNotEmpty) {
      final last = sections.removeLast();
      sections.add(
        Section(title: last.title, blocks: [...last.blocks, ...carried]),
      );
    }
    // The cover is the first page, unless the text already opens with it.
    if (cover != null && sections.isNotEmpty) {
      final first = sections.first;
      final opening = first.blocks.takeWhile((b) => b is! ParagraphBlock);
      if (!opening.any((b) => b is ImageBlock && b.assetId == cover.assetId)) {
        sections[0] = Section(
          title: first.title,
          blocks: [cover, ...first.blocks],
        );
      }
    }
    final notes = <String, Note>{};
    for (final MapEntry(:key, :value) in _notes.entries) {
      final blocks = resolve(value.blocks);
      if (blocks.isNotEmpty) {
        notes[key] = Note(label: value.label, blocks: blocks);
      }
    }
    final last = sections.length - 1;
    return BookContent(
      meta: BookMeta(
        title: _bookTitle ?? fallbackTitle,
        authors: _authors,
        series: _series,
        seriesNumber: _seriesNumber,
        lang: _lang,
        annotation: _annotation,
        coverAssetId: cover?.assetId,
        sourceFormat: format,
      ),
      toc: [
        for (final t in _toc)
          TocEntry(
            title: t.title,
            level: t.level,
            sectionIndex: newIndex[t.sectionIndex] > last
                ? last
                : newIndex[t.sectionIndex],
          ),
      ],
      sections: sections,
      notes: notes,
    );
  }
}

/// A footnote section of a `notes` body being read.
final class _OpenNote {
  _OpenNote(this.id, this.depth);

  final String id;

  /// Depth of its `section`.
  final int depth;
  String? label;
}

final class _Link {
  _Link(this.depth, this.noteId, {required this.isNote});

  final int depth;

  /// The `href` without `#`; empty when there is none.
  final String noteId;

  /// `type="note"`: a label whatever its text.
  final bool isNote;
  final text = StringBuffer();
}
