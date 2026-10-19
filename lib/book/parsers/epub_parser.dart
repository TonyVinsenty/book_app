/// EPUB 2 and 3 books (ADR 0005, addendum 1): `container.xml` → OPF
/// (metadata, manifest, spine) → every spine file is read as a stream of
/// XML events into blocks. Lenient: HTML5 entities, unclosed tags and
/// broken markup are stepped over; a broken or missing spine file is
/// skipped. For now a chapter is a spine file; pictures and footnotes are
/// skipped, as in FB2.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:book_app/book/encoding/text_decoder.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/parsers/parse_utils.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

/// Bump when the result for the same file changes (books get re-parsed).
const epubParserVersion = 1;

/// Not a readable EPUB: no OPF, an empty spine or no text at all.
final class NotEpubException implements Exception {
  const NotEpubException();

  @override
  String toString() => 'NotEpubException';
}

/// The text is encrypted (DRM); such books can't be read.
final class EpubDrmException implements Exception {
  const EpubDrmException();

  @override
  String toString() => 'EpubDrmException';
}

/// [title] is used when the book has no `dc:title` (usually the file name).
/// Throws [NotEpubException] or [EpubDrmException].
BookContent parseEpub(Uint8List bytes, {required String title}) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } on Object {
    throw const NotEpubException();
  }
  final files = _Files(archive);
  final opfPath = _rootFilePath(files);
  final opf = opfPath == null ? null : files.text(opfPath);
  if (opf == null) throw const NotEpubException();
  final package = _Package(_dirOf(opfPath!))..walk(opf);
  final spine = package.spinePaths();
  if (spine.isEmpty) throw const NotEpubException();
  // Obfuscated fonts are listed in `encryption.xml` too; only encrypted
  // text matters.
  final encrypted = _encryptedPaths(files);
  if (spine.any((p) => encrypted.contains(p.toLowerCase()))) {
    throw const EpubDrmException();
  }

  final sections = <Section>[];
  final toc = <TocEntry>[];
  for (final path in spine) {
    final text = files.text(path);
    if (text == null) continue;
    final List<Block> blocks;
    try {
      blocks = (_Xhtml()..walk(text)).finish();
    } on Object {
      // A parser bug on one strange file must not lose the whole book.
      continue;
    }
    // Covers and pictures without text.
    if (!blocks.any((b) => b is TextBlock)) continue;
    // A heading further down (`Примечания` after the text) is not the
    // title of the file.
    final first = blocks.first;
    final sectionTitle = first is HeadingBlock ? tocTitle(first.text) : null;
    if (sectionTitle != null) {
      toc.add(
        TocEntry(title: sectionTitle, level: 0, sectionIndex: sections.length),
      );
    }
    sections.add(Section(title: sectionTitle, blocks: blocks));
  }
  if (sections.isEmpty) {
    // DRM whose `encryption.xml` names the text some other way (Adobe
    // rights, Apple sinf); fonts alone are listed in DRM-free books too.
    if (_drmFiles.any(files.has)) throw const EpubDrmException();
    throw const NotEpubException();
  }
  return BookContent(
    meta: package.meta(fallbackTitle: title),
    toc: toc,
    sections: sections,
  );
}

const _drmFiles = ['META-INF/rights.xml', 'META-INF/sinf.xml'];

/// A spine file bigger than this (unpacked) is skipped.
const _maxEntrySize = 50 * 1024 * 1024;

/// The archive entries by path; a wrong letter case in a link still finds
/// the file (books made on Windows).
final class _Files {
  _Files(Archive archive) {
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll(r'\', '/');
      _byName[name] = file;
      _byLowerName.putIfAbsent(name.toLowerCase(), () => file);
    }
  }

  final _byName = <String, ArchiveFile>{};
  final _byLowerName = <String, ArchiveFile>{};

  Iterable<String> get names => _byName.keys;

  ArchiveFile? _find(String path) =>
      _byName[path] ?? _byLowerName[path.toLowerCase()];

  bool has(String path) => _find(path) != null;

  /// Null when the file is missing, too big or can't be unpacked.
  String? text(String path) {
    final file = _find(path);
    if (file == null || file.size > _maxEntrySize) return null;
    try {
      final bytes = file.readBytes();
      if (bytes == null) return null;
      return decodeText(bytes, declared: _declaredEncoding(bytes)).text;
    } on Object {
      return null;
    }
  }
}

final _charset = RegExp(
  r'''(?:encoding|charset)\s*=\s*["']?([A-Za-z0-9_-]+)''',
  caseSensitive: false,
);

/// `encoding=` of the XML declaration or `charset=` of an HTML `<meta>`.
TextEncoding? _declaredEncoding(Uint8List bytes) {
  final head = latin1.decode(
    Uint8List.sublistView(bytes, 0, bytes.length < 1024 ? bytes.length : 1024),
  );
  final match = _charset.firstMatch(head);
  return match == null ? null : encodingByName(match[1]!);
}

String _dirOf(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0 ? '' : path.substring(0, slash + 1);
}

/// [href] of a link in a file from [dir], as an archive path: without the
/// `#anchor`, percent-decoded, `..` resolved.
String _resolve(String dir, String href) {
  var path = href.trim();
  final cut = path.indexOf(RegExp('[#?]'));
  if (cut >= 0) path = path.substring(0, cut);
  try {
    path = Uri.decodeComponent(path);
  } on ArgumentError {
    // A stray `%` in a file name: keep it as is.
  }
  final parts = <String>[];
  final full = path.startsWith('/') ? path.substring(1) : '$dir$path';
  for (final part in full.replaceAll(r'\', '/').split('/')) {
    if (part == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else if (part.isNotEmpty && part != '.') {
      parts.add(part);
    }
  }
  return parts.join('/');
}

/// The OPF named by `container.xml`, or any `.opf` file when that is broken.
String? _rootFilePath(_Files files) {
  final container = files.text('META-INF/container.xml');
  if (container != null) {
    final reader = _Container()..walk(container);
    for (final path in reader.paths) {
      if (files.has(path)) return path;
    }
  }
  return files.names.where((n) => n.toLowerCase().endsWith('.opf')).firstOrNull;
}

Set<String> _encryptedPaths(_Files files) {
  final xml = files.text('META-INF/encryption.xml');
  if (xml == null) return const {};
  final reader = _Encryption()..walk(xml);
  return reader.paths;
}

/// More syntax errors than one per this many chars: the file is not XML
/// at all, and the rest of it is not read.
const _charsPerXmlError = 20;

/// What is left of a broken tag after the parser stepped over its `<`.
final _brokenTagRest = RegExp(r'^/?[A-Za-z][\w:.-]*(\s[^<>]*)?/?>');

/// Reads XML as a stream of events. Element names come lowercased and
/// without a prefix (`dc:title` → `title`); attribute names lowercased with
/// it (`epub:type`). A syntax error skips the broken markup and goes on.
abstract class _Walker {
  void start(
    String name,
    Map<String, String> attributes, {
    required bool selfClosing,
  });

  void end(String name);

  void text(String value);

  void walk(String xml) {
    final events = parseEvents(
      xml,
      entityMapping: const XmlDefaultEntityMapping.html5(),
    ).iterator;
    final maxErrors = 100 + xml.length ~/ _charsPerXmlError;
    var errors = 0;
    var afterError = false;
    while (true) {
      try {
        if (!events.moveNext()) return;
      } on XmlException {
        // The parser has stepped over one char; go on from there.
        if (++errors > maxErrors) return;
        afterError = true;
        continue;
      }
      final broken = afterError;
      afterError = false;
      switch (events.current) {
        case XmlStartElementEvent(:final name, :final attributes) &&
            final event:
          start(_local(name), {
            for (final a in attributes) a.name.toLowerCase(): a.value,
          }, selfClosing: event.isSelfClosing);
        case XmlEndElementEvent(:final name):
          end(_local(name));
        case XmlTextEvent(:final value):
          var rest = value;
          // Errors start at a `<`: a broken tag is dropped, a bare `<` in
          // the text (`1 < 2`) is put back.
          if (broken) {
            final tag = _brokenTagRest.firstMatch(rest);
            rest = tag != null ? rest.substring(tag.end) : '<$rest';
          }
          if (rest.isNotEmpty) text(rest);
        case XmlCDATAEvent(:final value):
          text(value);
        default:
          break;
      }
    }
  }

  static String _local(String name) {
    final colon = name.indexOf(':');
    return (colon < 0 ? name : name.substring(colon + 1)).toLowerCase();
  }
}

final class _Container extends _Walker {
  final paths = <String>[];

  @override
  void start(
    String name,
    Map<String, String> attributes, {
    required bool selfClosing,
  }) {
    if (name != 'rootfile') return;
    final path = attributes['full-path'];
    if (path == null || path.trim().isEmpty) return;
    final type = attributes['media-type'];
    // The OPF goes first; other renditions (rare) after it.
    if (type == null || type == 'application/oebps-package+xml') {
      paths.insert(0, _resolve('', path));
    } else {
      paths.add(_resolve('', path));
    }
  }

  @override
  void end(String name) {}

  @override
  void text(String value) {}
}

/// Lowercased paths of the encrypted files (from the archive root).
final class _Encryption extends _Walker {
  final paths = <String>{};

  @override
  void start(
    String name,
    Map<String, String> attributes, {
    required bool selfClosing,
  }) {
    if (name != 'cipherreference') return;
    final uri = attributes['uri'];
    if (uri != null) paths.add(_resolve('', uri).toLowerCase());
  }

  @override
  void end(String name) {}

  @override
  void text(String value) {}
}

final class _Item {
  const _Item(this.path, this.mediaType);

  final String path;
  final String mediaType;
}

final class _Creator {
  const _Creator(this.name, this.id, this.role);

  final String name;
  final String? id;
  final String? role;
}

/// The OPF package: metadata, manifest and spine.
final class _Package extends _Walker {
  _Package(this._dir);

  final String _dir;
  final _manifest = <String, _Item>{};
  final _spine = <String>[];

  final _titles = <(String, String?)>[];
  final _creators = <_Creator>[];
  String? _language;
  String? _description;
  String? _calibreSeries;
  String? _calibreSeriesIndex;

  /// EPUB 3 `belongs-to-collection`: (id, name) in file order.
  final _collections = <(String?, String)>[];

  /// EPUB 3 `<meta refines="#id" property="…">`: id → property → value.
  final _refines = <String, Map<String, String>>{};

  var _inMetadata = false;
  StringBuffer? _field;
  String? _fieldName;
  Map<String, String> _fieldAttributes = const {};

  @override
  void start(
    String name,
    Map<String, String> attributes, {
    required bool selfClosing,
  }) {
    switch (name) {
      case 'metadata':
        _inMetadata = true;
      case 'item':
        final id = attributes['id'];
        final href = attributes['href'];
        if (id != null && href != null) {
          _manifest[id] = _Item(
            _resolve(_dir, href),
            attributes['media-type']?.toLowerCase() ?? '',
          );
        }
      case 'itemref':
        final id = attributes['idref'];
        if (id != null) _spine.add(id);
      case 'meta' when _inMetadata:
        switch (attributes['name']) {
          case 'calibre:series':
            _calibreSeries ??= attributes['content'];
          case 'calibre:series_index':
            _calibreSeriesIndex ??= attributes['content'];
        }
        if (attributes['property'] != null) _startField(name, attributes);
      case 'title' || 'creator' || 'language' || 'description' when _inMetadata:
        _startField(name, attributes);
    }
    if (selfClosing) end(name);
  }

  void _startField(String name, Map<String, String> attributes) {
    _field = StringBuffer();
    _fieldName = name;
    _fieldAttributes = attributes;
  }

  @override
  void end(String name) {
    if (name == 'metadata') _inMetadata = false;
    if (name != _fieldName) return;
    final value = cleanSpaces(_field.toString());
    final attributes = _fieldAttributes;
    _field = _fieldName = null;
    if (value.isEmpty) return;
    final id = attributes['id'];
    switch (name) {
      case 'title':
        _titles.add((value, id));
      case 'creator':
        _creators.add(
          _Creator(value, id, attributes['opf:role'] ?? attributes['role']),
        );
      case 'language':
        _language ??= value.toLowerCase();
      case 'description':
        _description ??= value;
      case 'meta':
        final property = attributes['property']!;
        final refines = attributes['refines'];
        if (refines != null && refines.startsWith('#')) {
          (_refines[refines.substring(1)] ??= {})[property] = value;
        } else if (property == 'belongs-to-collection') {
          _collections.add((id, value));
        }
    }
  }

  @override
  void text(String value) => _field?.write(value);

  /// Spine documents in reading order (`linear="no"` too), each once.
  List<String> spinePaths() {
    final paths = <String>[];
    for (final id in _spine) {
      final item = _manifest[id];
      if (item == null || !_isDocument(item)) continue;
      if (!paths.contains(item.path)) paths.add(item.path);
    }
    return paths;
  }

  static bool _isDocument(_Item item) {
    final type = item.mediaType;
    return !(type.startsWith('image/') ||
        type.startsWith('audio/') ||
        type.startsWith('video/') ||
        type.contains('css') ||
        type.contains('font') ||
        type.contains('ncx'));
  }

  String? _refined(String? id, String property) =>
      id == null ? null : _refines[id]?[property];

  BookMeta meta({required String fallbackTitle}) {
    final mainTitle = _titles
        .where((t) => _refined(t.$2, 'title-type') == 'main')
        .firstOrNull;
    final authors = [
      for (final c in _creators)
        if ((c.role ?? _refined(c.id, 'role') ?? 'aut') == 'aut') c.name,
    ];
    var series = _calibreSeries?.trim();
    var number = _calibreSeriesIndex;
    if (series == null || series.isEmpty) {
      final collection = _collections
          .where(
            (c) => (_refined(c.$1, 'collection-type') ?? 'series') == 'series',
          )
          .firstOrNull;
      series = collection?.$2;
      number = _refined(collection?.$1, 'group-position');
    }
    return BookMeta(
      title: (mainTitle ?? _titles.firstOrNull)?.$1 ?? fallbackTitle,
      authors: authors,
      series: series,
      seriesNumber: series == null ? null : _wholeNumber(number),
      lang: _language,
      annotation: _description == null ? null : _plainText(_description!),
      sourceFormat: SourceFormat.epub,
    );
  }
}

/// `2` and `2.0` → 2; `2.5` or junk → null.
int? _wholeNumber(String? s) {
  final n = double.tryParse(s?.trim() ?? '');
  return n != null && n.isFinite && n == n.roundToDouble() ? n.toInt() : null;
}

final _lineTag = RegExp(r'</p\s*>|<br\s*/?>', caseSensitive: false);
final _tag = RegExp('<[^>]*>');

/// `dc:description` often holds escaped HTML (Calibre): one line per
/// paragraph, tags dropped.
String? _plainText(String html) {
  final text = const XmlDefaultEntityMapping.html5()
      .decode(html.replaceAll(_lineTag, '\n').replaceAll(_tag, ''))
      .split('\n')
      .map(cleanSpaces)
      .where((line) => line.isNotEmpty)
      .join('\n');
  return text.isEmpty ? null : text;
}

const _blockTags = {
  'address',
  'article',
  'aside',
  'blockquote',
  'body',
  'caption',
  'center',
  'dd',
  'details',
  'div',
  'dl',
  'dt',
  'fieldset',
  'figcaption',
  'figure',
  'footer',
  'form',
  'header',
  'hgroup',
  'html',
  'legend',
  'li',
  'main',
  'nav',
  'ol',
  'p',
  'pre',
  'section',
  'summary',
  'table',
  'tbody',
  'tfoot',
  'thead',
  'tr',
  'ul',
};

/// Elements that never have content or an end tag in HTML.
const _voidTags = {
  'area',
  'base',
  'br',
  'col',
  'embed',
  'hr',
  'img',
  'input',
  'link',
  'meta',
  'param',
  'source',
  'track',
  'wbr',
};

/// Everything inside is not text of the book.
const _skipTags = {
  'audio',
  'canvas',
  'head',
  'iframe',
  'map',
  'math',
  'object',
  'rp',
  'rt',
  'script',
  'select',
  'style',
  'svg',
  'template',
  'video',
};

const _noteTypes = {
  'footnote',
  'footnotes',
  'endnote',
  'endnotes',
  'rearnote',
  'rearnotes',
  'note',
  'notes',
};

final _headingTag = RegExp(r'^h([1-6])$');

/// The text of a link that is a footnote mark: `[12]`, `{3}`, `*`.
final _noteMark = RegExp(r'^(?:[\[{]\d{1,4}[\]}]|\*{1,3})$');

/// `1` or `(1)`: a footnote mark only in a link that looks like a note
/// ([_Element.noteLike]); `в 1812 году` keeps its year.
final _numberMark = RegExp(r'^\(?\d{1,4}\)?$');

final _noteHref = RegExp(r'note|fn|#n[_-]?\d', caseSensitive: false);

/// A heading longer than this is a heading never closed (broken HTML):
/// the next block is a paragraph.
const _maxHeadingLength = 200;

/// Hidden navigation of EPUB 3, not text of the book.
const _hiddenNavTypes = {'landmarks', 'page-list'};

final _poemClass = RegExp('poem|stanza|verse|poetry');
final _quoteClass = RegExp(r'\b(cite|citation|quote|blockquote)\b');

enum _Look { epigraph, poem, subtitle, quote }

final class _Element {
  _Element(this.name);

  final String name;

  /// The look this element gives the paragraphs inside it.
  _Look? look;

  /// A link that may turn out to be a footnote mark: the text before it.
  _Text? linkText;
  _Mark? linkMark;

  /// The link points to a note or is set as a superscript.
  var noteLike = false;
}

/// A state of [_Text] to go back to.
typedef _Mark = ({int length, bool space, bool lineStart});

/// A text block being collected: whitespace runs become one space, soft
/// hyphens are dropped, `<br>` lines are joined with `\n`.
final class _Text {
  _Text(this.style, {this.heading, this.owner = 0});

  final ParagraphStyle style;

  /// Level for a heading (`h1`–`h6`), null for a paragraph.
  final int? heading;

  /// Depth of the heading element.
  final int owner;

  var _buffer = StringBuffer();
  final spans = <Span>[];
  final _open = <(int, SpanKind)>[];
  var _space = false;
  var _lineStart = true;

  int get length => _buffer.length;

  void add(String s, {required bool keepLines}) {
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c == 0x0A && keepLines) {
        lineBreak();
      } else if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        if (!_lineStart) _space = true;
      } else if (c != 0xAD && c != 0xFEFF) {
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

  _Mark mark() =>
      (length: _buffer.length, space: _space, lineStart: _lineStart);

  String textSince(_Mark mark) => _buffer.toString().substring(mark.length);

  /// Drops the text added after [mark].
  void rollback(_Mark mark) {
    final length = mark.length;
    _buffer = StringBuffer(_buffer.toString().substring(0, length));
    _space = mark.space;
    _lineStart = mark.lineStart;
    for (var i = spans.length - 1; i >= 0; i--) {
      final s = spans[i];
      if (s.start >= length) {
        spans.removeAt(i);
      } else if (s.end > length) {
        spans[i] = Span(s.start, length, s.kind);
      }
    }
    for (var i = 0; i < _open.length; i++) {
      if (_open[i].$1 > length) _open[i] = (length, _open[i].$2);
    }
  }

  /// The text without blank edges (`&nbsp;` indents too); null when blank.
  String? finish() {
    while (_open.isNotEmpty) {
      closeSpan(_open.last.$2);
    }
    final text = _buffer.toString();
    var start = 0;
    var end = text.length;
    while (start < end && _isBlank(text.codeUnitAt(start))) {
      start++;
    }
    while (end > start && _isBlank(text.codeUnitAt(end - 1))) {
      end--;
    }
    if (start == end) return null;
    final length = end - start;
    final shifted = <Span>[];
    for (final s in spans) {
      final from = (s.start - start).clamp(0, length);
      final to = (s.end - start).clamp(0, length);
      if (from < to) shifted.add(Span(from, to, s.kind));
    }
    spans
      ..clear()
      ..addAll(shifted)
      ..sort((a, b) => a.start - b.start);
    return text.substring(start, end);
  }

  static bool _isBlank(int c) =>
      c == 0x20 ||
      c == 0x0A ||
      c == 0xA0 ||
      c == 0x2007 ||
      c == 0x202F ||
      c == 0x200B ||
      c == 0x3000;
}

/// One XHTML file → blocks (ADR 0005): `h1`–`h6` → headings, `p`, `div`,
/// `li`… → paragraphs, `hr` → a separator, `em`/`i` and `strong`/`b` →
/// spans; poems and epigraphs by `class`; CSS is not read.
final class _Xhtml extends _Walker {
  final _blocks = <Block>[];
  final _stack = <_Element>[];

  /// Everything inside the element at this depth is ignored.
  int? _skip;
  _Text? _text;

  @override
  void start(
    String name,
    Map<String, String> attributes, {
    required bool selfClosing,
  }) {
    final element = _Element(name);
    _stack.add(element);
    if (_skip == null) _open(element, attributes);
    if (selfClosing || _voidTags.contains(name)) _pop();
  }

  @override
  void end(String name) {
    // Unclosed tags inside are closed together with this one.
    final i = _stack.lastIndexWhere((e) => e.name == name);
    if (i < 0) return;
    while (_stack.length > i) {
      _pop();
    }
  }

  @override
  void text(String value) {
    if (_skip != null || _stack.isEmpty) return;
    if (_text == null && value.trim().isEmpty) return;
    _current().add(value, keepLines: _stack.any((e) => e.name == 'pre'));
  }

  List<Block> finish() {
    _flush();
    return _blocks;
  }

  void _pop() {
    final depth = _stack.length;
    final element = _stack.removeLast();
    if (_skip != null) {
      if (depth == _skip) _skip = null;
      return;
    }
    _close(element, depth);
  }

  void _open(_Element element, Map<String, String> attributes) {
    final depth = _stack.length;
    final name = element.name;
    final types = _epubTypes(attributes);
    final role = attributes['role'] ?? '';
    if (_skipTags.contains(name) ||
        attributes.containsKey('hidden') ||
        (name == 'nav' && types.any(_hiddenNavTypes.contains)) ||
        types.any(_noteTypes.contains) ||
        (role.startsWith('doc-') &&
            role.contains('note') &&
            role != 'doc-noteref')) {
      _skip = depth;
      return;
    }
    element.look = _look(name, attributes['class']?.toLowerCase(), types);
    final heading = _headingTag.firstMatch(name);
    if (heading != null) {
      _flush();
      _openStackSpans(
        _text = _Text(
          ParagraphStyle.normal,
          heading: int.parse(heading[1]!),
          owner: depth,
        ),
      );
      return;
    }
    switch (name) {
      case 'br':
        _text?.lineBreak();
      case 'hr':
        _flush();
        _addSeparator();
      case 'td' || 'th':
        _text?.gap();
      // A paragraph started later gets it from the stack (`_current`).
      case 'em' || 'i' || 'cite' || 'dfn' || 'var' || 'strong' || 'b':
        _text?.openSpan(_spanKind(name)!);
      case 'sup':
        for (final e in _stack) {
          if (e.linkMark != null) e.noteLike = true;
        }
      case 'a':
        final href = attributes['href'] ?? '';
        if (types.contains('noteref') || role == 'doc-noteref') {
          _skip = depth;
        } else if (href.contains('#')) {
          final text = element.linkText = _current();
          element.linkMark = text.mark();
          element.noteLike =
              _noteHref.hasMatch(href) ||
              (attributes['class']?.contains('note') ?? false) ||
              _stack.any((e) => e.name == 'sup');
        }
      case _ when _blockTags.contains(name):
        _blockBoundary(depth);
    }
  }

  void _close(_Element element, int depth) {
    if (_headingTag.hasMatch(element.name)) {
      _flush();
      return;
    }
    switch (element.name) {
      case 'em' || 'i' || 'cite' || 'dfn' || 'var' || 'strong' || 'b':
        _text?.closeSpan(_spanKind(element.name)!);
      // A footnote mark like `[1]` linking to the notes file: not a word.
      case 'a':
        final text = element.linkText;
        final mark = element.linkMark;
        if (text != null && mark != null && identical(text, _text)) {
          final linkText = text.textSince(mark).trim();
          if (_noteMark.hasMatch(linkText) ||
              (element.noteLike && _numberMark.hasMatch(linkText))) {
            text.rollback(mark);
          }
        }
      case final name when _blockTags.contains(name):
        _blockBoundary(depth);
    }
  }

  /// A block starts or ends: the paragraph ends, but a heading only gets a
  /// new line (`<h2><p>Глава 1</p><p>Начало</p></h2>`).
  void _blockBoundary(int depth) {
    if (_text case final text?
        when text.heading != null &&
            text.owner < depth &&
            text.length < _maxHeadingLength) {
      text.lineBreak();
    } else {
      _flush();
    }
  }

  static Set<String> _epubTypes(Map<String, String> attributes) => {
    for (final MapEntry(:key, :value) in attributes.entries)
      if (key.endsWith(':type'))
        ...value.toLowerCase().split(whitespacePattern),
  };

  static _Look? _look(String name, String? classes, Set<String> types) {
    if (types.contains('epigraph')) return _Look.epigraph;
    if (classes != null) {
      if (classes.contains('epigraph')) return _Look.epigraph;
      if (_poemClass.hasMatch(classes)) return _Look.poem;
      if (classes.contains('subtitle')) return _Look.subtitle;
      if (_quoteClass.hasMatch(classes)) return _Look.quote;
    }
    return name == 'blockquote' ? _Look.quote : null;
  }

  _Text _current() {
    if (_text case final text?) return text;
    final text = _text = _Text(_style());
    _openStackSpans(text);
    return text;
  }

  /// `<em><p>…</p></em>`: the span outlives the paragraph it began in.
  void _openStackSpans(_Text text) {
    for (final e in _stack) {
      if (_spanKind(e.name) case final kind?) text.openSpan(kind);
    }
  }

  static SpanKind? _spanKind(String name) => switch (name) {
    'em' || 'i' || 'cite' || 'dfn' || 'var' => SpanKind.emphasis,
    'strong' || 'b' => SpanKind.strong,
    _ => null,
  };

  /// An epigraph wins (a poem in an epigraph is still an epigraph), then a
  /// poem, a subtitle, a quote.
  ParagraphStyle _style() {
    final looks = {for (final e in _stack) ?e.look};
    if (looks.contains(_Look.epigraph)) return ParagraphStyle.epigraph;
    if (looks.contains(_Look.poem)) return ParagraphStyle.poem;
    if (looks.contains(_Look.subtitle)) return ParagraphStyle.subtitle;
    if (looks.contains(_Look.quote)) return ParagraphStyle.quote;
    return ParagraphStyle.normal;
  }

  void _flush() {
    final text = _text;
    if (text == null) return;
    _text = null;
    final value = text.finish();
    if (value == null) return;
    if (text.heading case final level?) {
      _blocks.add(HeadingBlock(text: value, level: level, spans: text.spans));
    } else if (separatorPattern.hasMatch(value)) {
      _addSeparator();
    } else {
      _blocks.add(
        ParagraphBlock(text: value, style: text.style, spans: text.spans),
      );
    }
  }

  void _addSeparator() {
    if (_blocks.isNotEmpty && _blocks.last is! SeparatorBlock) {
      _blocks.add(const SeparatorBlock());
    }
  }
}
