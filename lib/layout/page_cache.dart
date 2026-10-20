import 'dart:convert';
import 'dart:io';

import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';

/// Version of the page split rules: bump it on any change to how pages are
/// split, to [PageStyle] or to the font files (`tool/fonts`), so old saved
/// splits are not used (ADR 0003, addendum 2 п. 7).
const layoutVersion = 1;

/// Everything the page breaks of a book depend on (ADR 0003, addendum 2
/// п. 7); colors are not in it.
String layoutKeyOf({
  required PageStyle style,
  required Size pageSize,
  required int parserVersion,
}) => [
  'v$layoutVersion',
  'p$parserVersion',
  't$tokenizerVersion',
  style.fontFamily,
  style.textScaler.scale(style.fontSize),
  style.lineHeight,
  style.align.name,
  '${pageSize.width.toStringAsFixed(1)}x${pageSize.height.toStringAsFixed(1)}',
].join('|');

/// First words of each chapter's pages; null for a chapter not split.
typedef ChapterPages = List<List<int>?>;

/// Page splits of one book on disk (ADR 0003, addendum 2 п. 7–8):
/// `<dir>/<hash of the key>.json`, the [keep] last used ones. Best effort:
/// a missing, broken or unreadable file is just no cache. Synchronous: a
/// file is tens of kilobytes, and the page count is then right on the
/// first frame.
final class PageCache {
  PageCache(this.dir, {this.keep = 3, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// `books/<id>/pages/`; removed with the book.
  final Directory dir;
  final int keep;
  final DateTime Function() _now;

  File fileOf(String key) => File(
    '${dir.path}${Platform.pathSeparator}'
    '${sha256.convert(utf8.encode(key)).toString().substring(0, 16)}.json',
  );

  /// The saved split for [key], if it fits a book of [sections] chapters
  /// and [words] words; marks it as just used.
  ChapterPages? load(String key, {required int sections, required int words}) {
    final file = fileOf(key);
    try {
      if (!file.existsSync()) return null;
      final json = jsonDecode(file.readAsStringSync());
      final chapters = _parse(json, key, sections, words);
      if (chapters != null) {
        file.setLastModifiedSync(_now());
        return chapters;
      }
    } catch (_) {
      // Broken: removed below.
    }
    try {
      file.deleteSync();
    } catch (_) {}
    return null;
  }

  /// Writes the split for [key] and removes all but the [keep] last used.
  /// Through a temporary file, so a half-written file never has the name.
  void save(String key, ChapterPages chapters) {
    try {
      dir.createSync(recursive: true);
      final target = fileOf(key);
      File('${target.path}.tmp')
        ..writeAsStringSync(jsonEncode({'key': key, 'chapters': chapters}))
        ..renameSync(target.path);
      target.setLastModifiedSync(_now());
      _prune();
    } catch (_) {
      // No cache this time; the book is split again next time.
    }
  }

  void _prune() {
    final files = [
      for (final entity in dir.listSync())
        if (entity is File && entity.path.endsWith('.json')) entity,
    ];
    if (files.length <= keep) return;
    final used = {for (final f in files) f: f.lastModifiedSync()};
    files.sort((a, b) => used[b]!.compareTo(used[a]!));
    for (final file in files.skip(keep)) {
      file.deleteSync();
    }
  }

  /// Null unless the file is for [key] and every chapter's first words go
  /// up within the book.
  static ChapterPages? _parse(
    Object? json,
    String key,
    int sections,
    int words,
  ) {
    if (json is! Map || json['key'] != key) return null;
    final chapters = json['chapters'];
    if (chapters is! List || chapters.length != sections) return null;
    final result = <List<int>?>[];
    for (final chapter in chapters) {
      if (chapter == null) {
        result.add(null);
        continue;
      }
      if (chapter is! List) return null;
      final pages = <int>[];
      for (final word in chapter) {
        if (word is! int || word < 0 || word >= words) return null;
        if (pages.isNotEmpty && word <= pages.last) return null;
        pages.add(word);
      }
      result.add(List.unmodifiable(pages));
    }
    return result;
  }
}
