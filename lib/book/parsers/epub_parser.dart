/// EPUB 2 and 3 books (ADR 0005, addendum 1): `container.xml` → OPF
/// (metadata, manifest, spine) → every spine file is read as a stream of
/// XML events into blocks. Lenient: HTML5 entities, unclosed tags and
/// broken markup are stepped over; a broken or missing spine file is
/// skipped. Chapters follow the book's contents (EPUB 3 `nav` or EPUB 2
/// NCX); pictures and footnotes are skipped, as in FB2.
library;

import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:book_app/book/encoding/text_decoder.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/book/parsers/parse_utils.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

/// Bump when the result for the same file changes (books get re-parsed).
const epubParserVersion = 2;

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

  final contents = _readContents(files, package, spine);
  final entriesOf = <String, List<_Entry>>{};
  for (final entry in contents) {
    (entriesOf[entry.path] ??= []).add(entry);
  }
  final chapters = _Chapters(contents);
  for (final path in spine) {
    final text = files.text(path);
    if (text == null) continue;
    final entries = entriesOf[path] ?? const <_Entry>[];
    final reader = _Xhtml({for (final e in entries) ?e.anchor});
    try {
      final blocks = (reader..walk(text)).finish();
      chapters.addFile(blocks, entries, reader.anchorBlocks);
    } on Object {
      // A parser bug on one strange file must not lose the whole book.
      continue;
    }
  }
  final (:sections, :toc) = chapters.finish();
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
  const _Item(this.path, this.mediaType, this.properties);

  final String path;
  final String mediaType;

  /// EPUB 3 `properties` (`nav`, `cover-image`).
  final Set<String> properties;
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

  /// The NCX id named by `<spine toc="…">` (EPUB 2).
  String? _spineToc;

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
            {...?attributes['properties']?.split(whitespacePattern)},
          );
        }
      case 'spine':
        _spineToc = attributes['toc'];
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

  /// The EPUB 3 navigation document.
  String? navPath() => _manifest.values
      .where((i) => i.properties.contains('nav'))
      .firstOrNull
      ?.path;

  /// The EPUB 2 NCX: named by the spine or found by its type.
  String? ncxPath() =>
      (_manifest[_spineToc] ??
              _manifest.values
                  .where((i) => i.mediaType == 'application/x-dtbncx+xml')
                  .firstOrNull)
          ?.path;

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
  _Xhtml([this._anchors = const {}]);

  /// Ids the contents links to.
  final Set<String> _anchors;

  /// Id from [_anchors] → index of the first block at or after it; the text
  /// being collected there belongs to that block.
  final anchorBlocks = <String, int>{};

  /// Anchors met inside a paragraph after some of its text: they point
  /// after it.
  final _afterText = <String>[];

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
    if (_anchors.isNotEmpty) {
      final id = attributes['id'] ?? (name == 'a' ? attributes['name'] : null);
      if (id != null &&
          _anchors.contains(id) &&
          !anchorBlocks.containsKey(id) &&
          !_afterText.contains(id)) {
        // `<p>Конец части.<a id="ch4"/></p>`: the paragraph stays before
        // the anchor; a heading begun (`<h2>Глава <a id="ch1"/>I</h2>`)
        // goes after it.
        if (_text case final text?
            when text.heading == null && text.length > 0) {
          _afterText.add(id);
        } else {
          anchorBlocks[id] = _blocks.length;
        }
      }
    }
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
    _addText(text);
    for (final id in _afterText) {
      anchorBlocks[id] = _blocks.length;
    }
    _afterText.clear();
  }

  void _addText(_Text text) {
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

/// A line of the contents as written: [href] is null for a label without
/// a link (`<span>Часть 1</span>` over its chapters).
typedef _Link = ({String title, int level, String? href});

/// A line of the contents pointing into a spine file.
final class _Entry {
  _Entry(this.title, this.level, this.path, this.anchor);

  final String title;
  final int level;

  /// The spine path, as in [_Package.spinePaths].
  final String path;
  final String? anchor;
}

/// The book's contents (EPUB 3 `nav`, else EPUB 2 NCX) as links into
/// [spine] files; empty when there is none or it leads nowhere.
List<_Entry> _readContents(_Files files, _Package package, List<String> spine) {
  final navPath = package.navPath();
  for (final path in [?navPath, ?package.ncxPath()]) {
    final xml = files.text(path);
    if (xml == null) continue;
    final List<_Link> links;
    try {
      links = path == navPath
          ? (_Nav()..walk(xml)).links()
          : (_Ncx()..walk(xml)).links;
    } on Object {
      continue;
    }
    final entries = _entries(links, path, spine);
    if (entries.isNotEmpty) return entries;
  }
  return const [];
}

/// [links] of the contents file at [path] that lead into [spine]. A label
/// without a link points where the next link does; levels start at 0.
List<_Entry> _entries(List<_Link> links, String path, List<String> spine) {
  final spineSet = spine.toSet();
  final spineByLower = {for (final p in spine) p.toLowerCase(): p};
  final dir = _dirOf(path);
  final entries = <_Entry>[];
  final labels = <_Link>[];
  for (final link in links) {
    if (link.title.isEmpty) continue;
    final href = link.href?.trim() ?? '';
    if (href.isEmpty) {
      labels.add(link);
      continue;
    }
    final hash = href.indexOf('#');
    final file = hash < 0 ? href : href.substring(0, hash);
    final resolved = file.isEmpty ? path : _resolve(dir, file);
    final target = spineSet.contains(resolved)
        ? resolved
        : spineByLower[resolved.toLowerCase()];
    // Links to the web or to files out of the spine.
    if (target == null) continue;
    final anchor = hash < 0 ? null : _decoded(href.substring(hash + 1));
    for (final l in [...labels, link]) {
      entries.add(_Entry(l.title, l.level, target, anchor));
    }
    labels.clear();
  }
  if (entries.isEmpty) return entries;
  final top = entries.map((e) => e.level).reduce((a, b) => a < b ? a : b);
  return [
    for (final e in entries) _Entry(e.title, e.level - top, e.path, e.anchor),
  ];
}

String? _decoded(String anchor) {
  var value = anchor.trim();
  try {
    value = Uri.decodeComponent(value);
  } on ArgumentError {
    // A stray `%`: keep it as is.
  }
  return value.isEmpty ? null : value;
}

/// One `nav` of a navigation document.
typedef _NavList = ({bool toc, bool hidden, List<_Link> links});

/// EPUB 3 navigation document: the `<nav epub:type="toc">` (or the first
/// shown `nav`); the `ol` nesting gives the levels.
final class _Nav extends _Walker {
  final _navs = <_NavList>[];
  final _stack = <String>[];
  int? _navDepth;
  var _lists = 0;

  /// Open `li`s: index of the line each one gave, -1 before it has one.
  final _items = <int>[];

  /// The link or label being read: its element depth, text and target.
  int? _labelDepth;
  StringBuffer? _label;
  String? _href;

  List<_Link> links() =>
      (_navs.where((n) => n.toc).firstOrNull ??
              _navs.where((n) => !n.hidden).firstOrNull)
          ?.links ??
      const [];

  @override
  void start(
    String name,
    Map<String, String> attributes, {
    required bool selfClosing,
  }) {
    if (selfClosing || _voidTags.contains(name)) return;
    _stack.add(name);
    if (_navDepth == null) {
      if (name != 'nav') return;
      final types = _Xhtml._epubTypes(attributes);
      _navDepth = _stack.length;
      _lists = 0;
      _items.clear();
      _navs.add((
        toc: types.contains('toc'),
        hidden:
            attributes.containsKey('hidden') ||
            types.any(_hiddenNavTypes.contains),
        links: <_Link>[],
      ));
      return;
    }
    if (name == 'ol' || name == 'ul') _lists++;
    if (name == 'li') _items.add(-1);
    // A line is the first link or label of its `li`; a heading over the
    // list is not one.
    if (_label == null &&
        _items.isNotEmpty &&
        (name == 'a' || name == 'span')) {
      _labelDepth = _stack.length;
      _label = StringBuffer();
      _href = name == 'a' ? attributes['href'] : null;
    }
  }

  @override
  void end(String name) {
    // Unclosed tags inside are closed together with this one.
    final i = _stack.lastIndexOf(name);
    if (i < 0) return;
    while (_stack.length > i) {
      _pop();
    }
  }

  void _pop() {
    final depth = _stack.length;
    final name = _stack.removeLast();
    if (_navDepth == null) return;
    if (depth == _labelDepth) {
      _line((
        title: cleanSpaces(_label.toString()),
        level: _lists < 1 ? 0 : _lists - 1,
        href: _href,
      ));
      _label = _href = _labelDepth = null;
    }
    if (name == 'ol' || name == 'ul') _lists--;
    if (name == 'li' && _items.isNotEmpty) _items.removeLast();
    if (depth == _navDepth) _navDepth = null;
  }

  /// `<li><span>1.</span> <a href="…">Глава</a></li>`: the link wins over
  /// a label before it; anything after is decoration.
  void _line(_Link line) {
    final links = _navs.last.links;
    final at = _items.last;
    if (line.title.isEmpty) return;
    if (at < 0) {
      _items.last = links.length;
      links.add(line);
    } else if (links[at].href == null && line.href != null) {
      links[at] = line;
    }
  }

  @override
  void text(String value) => _label?.write(value);
}

/// An open `navPoint`: its label, target and whether it is listed yet.
final class _NavPoint {
  final label = StringBuffer();
  String? src;
  var listed = false;
}

/// EPUB 2 NCX: `navMap` → nested `navPoint`s with a label and `content`.
final class _Ncx extends _Walker {
  final links = <_Link>[];
  final _points = <_NavPoint>[];
  var _inMap = false;
  var _inLabel = false;

  @override
  void start(
    String name,
    Map<String, String> attributes, {
    required bool selfClosing,
  }) {
    if (name == 'navmap') _inMap = !selfClosing;
    if (!_inMap) return;
    switch (name) {
      case 'navpoint':
        // A parent is listed before its children.
        if (_points.isNotEmpty) _list(_points.length - 1);
        _points.add(_NavPoint());
        if (selfClosing) end(name);
      case 'navlabel':
        _inLabel = !selfClosing;
      case 'content' when _points.isNotEmpty:
        _points.last.src ??= attributes['src'];
    }
  }

  @override
  void end(String name) {
    switch (name) {
      case 'navmap':
        while (_points.isNotEmpty) {
          end('navpoint');
        }
        _inMap = false;
      case 'navlabel':
        _inLabel = false;
      case 'navpoint' when _points.isNotEmpty:
        _list(_points.length - 1);
        _points.removeLast();
    }
  }

  void _list(int level) {
    final point = _points[level];
    if (point.listed) return;
    point.listed = true;
    links.add((
      title: cleanSpaces(point.label.toString()),
      level: level,
      href: point.src,
    ));
  }

  @override
  void text(String value) {
    if (_inLabel && _points.isNotEmpty && !_points.last.listed) {
      _points.last.label.write(value);
    }
  }
}

/// Spine files → chapters (ADR 0005, addendum 1). With contents: a chapter
/// starts at each link (a file or an anchor in it) and at a file that
/// begins with a heading; any other file goes on the chapter before (books
/// cut by size). Without contents: a chapter is a file. A chapter is named
/// by its link, else by the heading it starts with.
final class _Chapters {
  _Chapters(List<_Entry> contents)
    : _contents = [...contents],
      _byContents = contents.isNotEmpty;

  /// The links in order; chapters found by the parser are put in.
  final List<_Entry> _contents;
  final bool _byContents;

  /// Where the next found chapters go in [_contents], and the level of
  /// the chapters numbered `I`, `II`… in them.
  var _foundAt = 0;
  var _numberLevel = 0;

  /// The number a run of `I`, `II`… goes on from in the next file.
  var _nextNumber = 1;

  final _sections = <Section>[];
  final _sectionOf = HashMap<_Entry, int>.identity();

  /// The chapter being collected.
  List<Block>? _blocks;
  String? _title;

  /// Links to places without text (a cover), waiting for the next text.
  final _waiting = <_Entry>[];

  /// Links with a lost anchor: they go to the chapter of the next text
  /// without starting or naming it.
  final _unnamed = <_Entry>[];

  /// A link with a lost anchor → the link it goes with.
  final _follows = HashMap<_Entry, _Entry>.identity();

  /// [anchors]: anchor → block index, as [_Xhtml.anchorBlocks].
  void addFile(
    List<Block> blocks,
    List<_Entry> entries,
    Map<String, int> anchors,
  ) {
    final starts = SplayTreeMap<int, List<_Entry>>();
    // A link whose anchor is not in the file cuts nothing (no text is
    // lost) and points where the link before it does, or to the file
    // start without naming the chapter there.
    _Entry? before;
    for (final e in entries) {
      final at = e.anchor == null ? 0 : anchors[e.anchor];
      if (at == null) {
        if (before != null) {
          _follows[e] = before;
        } else {
          _unnamed.add(e);
        }
        continue;
      }
      (starts[at] ??= []).add(e);
      before = e;
    }
    if (entries.isNotEmpty) {
      _foundAt = _contents.indexOf(entries.last) + 1;
      _numberLevel = entries.first.level + 1;
      _nextNumber = 1;
    }
    // A file not in the contents that starts with a heading is a chapter
    // of its own, next to the one before.
    if (blocks.firstOrNull case HeadingBlock(:final text)
        when _byContents && starts[0] == null) {
      if (entries.isEmpty) {
        final level = _numberLevel < 1 ? 0 : _numberLevel - 1;
        final entry = _Entry(tocTitle(text), level, '', null);
        _contents.insert(_foundAt++, entry);
        starts[0] = [entry];
        _numberLevel = level + 1;
        _nextNumber = 1;
      } else {
        // Before the links further down the file.
        final entry = _Entry(tocTitle(text), entries.first.level, '', null);
        _contents.insert(_contents.indexOf(entries.first), entry);
        _foundAt++;
        starts[0] = [entry];
      }
    }
    // Wikisource: chapters `I`, `II`… as plain paragraphs, not in the
    // contents. They are taken when the contents does not cut the file;
    // the run goes on into files cut by size.
    if (!starts.keys.any((at) => at > 0)) {
      final numbered = _numbered(blocks, _nextNumber);
      _nextNumber += numbered.length;
      for (final i in numbered) {
        final number = blocks[i] as ParagraphBlock;
        blocks[i] = HeadingBlock(
          text: number.text,
          level: _numberLevel + 1,
          spans: number.spans,
        );
        if (starts[i] != null) continue;
        final entry = _Entry(number.text, _numberLevel, '', null);
        starts[i] = [entry];
        if (_byContents) _contents.insert(_foundAt++, entry);
      }
    }
    final cuts = {0, ...starts.keys}.toList()..sort();
    for (var i = 0; i < cuts.length; i++) {
      final from = cuts[i];
      final to = i + 1 < cuts.length ? cuts[i + 1] : blocks.length;
      final piece = blocks.sublist(from, to);
      final own = starts[from] ?? const <_Entry>[];
      _add(
        piece,
        own,
        newChapter: own.isNotEmpty || (from == 0 && !_byContents),
      );
    }
  }

  static final _roman = RegExp(
    r'^(C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})\.?$',
  );

  static const _romanValues = {'I': 1, 'V': 5, 'X': 10, 'L': 50, 'C': 100};

  /// Indexes of the paragraphs `I`, `II`, `III`… in a run from [first]:
  /// two or more from I, any going on from a file before.
  static List<int> _numbered(List<Block> blocks, int first) {
    final found = <int>[];
    for (final (i, block) in blocks.indexed) {
      if (block is ParagraphBlock &&
          block.style == ParagraphStyle.normal &&
          _romanNumber(block.text) == first + found.length) {
        found.add(i);
      }
    }
    return first == 1 && found.length < 2 ? const [] : found;
  }

  static int? _romanNumber(String text) {
    if (text.length > 10 || text.isEmpty || !_roman.hasMatch(text)) {
      return null;
    }
    final digits = text.endsWith('.')
        ? text.substring(0, text.length - 1)
        : text;
    var value = 0;
    for (var i = 0; i < digits.length; i++) {
      final digit = _romanValues[digits[i]]!;
      final next = i + 1 < digits.length ? _romanValues[digits[i + 1]]! : 0;
      value += digit < next ? -digit : digit;
    }
    return value;
  }

  void _add(List<Block> blocks, List<_Entry> own, {required bool newChapter}) {
    _waiting.addAll(own);
    // Covers and pictures without text.
    if (!blocks.any((b) => b is TextBlock)) return;
    final current = _blocks;
    final glue = current != null && !newChapter && _waiting.isEmpty;
    if (!glue) _close();
    for (final e in _unnamed) {
      _sectionOf[e] = _sections.length;
    }
    _unnamed.clear();
    if (glue) {
      current.addAll(
        current.last is SeparatorBlock
            ? blocks.skipWhile((b) => b is SeparatorBlock)
            : blocks,
      );
      return;
    }
    final chapter = blocks.skipWhile((b) => b is SeparatorBlock).toList();
    final first = chapter.first;
    // A heading further down (`Примечания` after the text) is not the
    // title of the file.
    final heading = first is HeadingBlock ? tocTitle(first.text) : null;
    final link = own.firstOrNull;
    _title = link?.title ?? heading;
    // `I` as a plain paragraph (Wikisource): the contents says it is the
    // chapter title.
    if (link != null &&
        first is ParagraphBlock &&
        first.text.length <= _maxHeadingLength &&
        _titleKey(first.text) == _titleKey(link.title)) {
      chapter[0] = HeadingBlock(
        text: first.text,
        level: link.level + 1,
        spans: first.spans,
      );
    }
    for (final e in _waiting) {
      _sectionOf[e] = _sections.length;
    }
    _waiting.clear();
    _blocks = chapter;
  }

  void _close() {
    final blocks = _blocks;
    if (blocks == null) return;
    while (blocks.last is SeparatorBlock) {
      blocks.removeLast();
    }
    _sections.add(Section(title: _title, blocks: blocks));
    _blocks = null;
  }

  ({List<Section> sections, List<TocEntry> toc}) finish() {
    _close();
    // Links after the last text point to the last chapter.
    for (final e in [..._waiting, ..._unnamed]) {
      _sectionOf[e] = _sections.length - 1;
    }
    for (final MapEntry(:key, :value) in _follows.entries) {
      if (_sectionOf[value] case final i?) _sectionOf[key] = i;
    }
    final toc = !_byContents
        ? [
            for (final (i, s) in _sections.indexed)
              if (s.title case final title?)
                TocEntry(title: title, level: 0, sectionIndex: i),
          ]
        : [
            for (final e in _contents)
              if (_sectionOf[e] case final i? when i >= 0)
                TocEntry(title: e.title, level: e.level, sectionIndex: i),
          ];
    return (sections: _sections, toc: toc);
  }

  static final _titleEnd = RegExp(r'[.:\s]+$');

  static String _titleKey(String s) =>
      cleanSpaces(s).toLowerCase().replaceAll(_titleEnd, '');
}
