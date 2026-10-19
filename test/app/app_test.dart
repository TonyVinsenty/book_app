import 'dart:convert';
import 'dart:io';

import 'package:book_app/app/app.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/features/library/library_screen.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Each test opens its own in-memory database.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('app_'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// Copies of [fixtures] in a "cache" folder, as the native picker returns.
  List<String> picked(List<String> fixtures) => [
    for (final (i, f) in fixtures.indexed)
      File(f).copySync('${temp.path}/pick$i-${f.split('/').last}').path,
  ];

  Future<void> pumpApp(WidgetTester tester, PickBooks pick) async {
    // Closing a drift database under fake time hangs, so it is left open;
    // synchronous stream closing leaves no pending timer.
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contentStoreProvider.overrideWithValue(
            ContentStore(Directory('${temp.path}/books')),
          ),
          pickBooksProvider.overrideWithValue(pick),
        ],
        child: const BookApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps "Add book" and lets the import (isolates, files) finish: the
  /// result message shows up.
  Future<void> addBooks(WidgetTester tester) async {
    await tester.tap(find.text('Добавить книгу'));
    await tester.runAsync(() async {
      for (
        var i = 0;
        i < 250 && find.byType(SnackBar).evaluate().isEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('empty library shows the Russian hint', (tester) async {
    await pumpApp(tester, () async => const []);

    expect(find.text('Здесь появятся ваши книги'), findsOneWidget);
    expect(find.text('Добавить книгу'), findsOneWidget);
    await closeApp(tester);
  });

  testWidgets('a picked book appears in the list', (tester) async {
    final paths = picked(['test/fixtures/fb2/utf8_nested.fb2']);
    await pumpApp(tester, () async => paths);

    await addBooks(tester);

    expect(find.byType(BookTile), findsOneWidget);
    expect(find.textContaining('Книга добавлена'), findsOneWidget);
    expect(File(paths.single).existsSync(), isFalse, reason: 'copy deleted');
    await closeApp(tester);
  });

  testWidgets('a row shows the cover or a letter, and the author', (
    tester,
  ) async {
    final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2];
    final fb2 = File('${temp.path}/cover.fb2')
      ..writeAsStringSync(
        '<FictionBook xmlns:l="http://www.w3.org/1999/xlink"><description>'
        '<title-info><author><first-name>Анна</first-name>'
        '<last-name>Ахматова</last-name></author>'
        '<book-title>Вечер</book-title>'
        '<coverpage><image l:href="#c"/></coverpage></title-info>'
        '</description><body><section><p>Раз два.</p></section></body>'
        '<binary id="c">${base64.encode(png)}</binary></FictionBook>',
      );
    final txt = picked(['test/fixtures/txt/utf8_lines.txt']).single;
    await pumpApp(tester, () async => [fb2.path, txt]);

    await addBooks(tester);

    expect(find.byType(BookTile), findsNWidgets(2));
    final withCover = find.ancestor(
      of: find.text('Вечер'),
      matching: find.byType(BookTile),
    );
    expect(
      find.descendant(of: withCover, matching: find.byType(Image)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: withCover, matching: find.text('Анна Ахматова')),
      findsOneWidget,
    );
    final plain = find.ancestor(
      of: find.textContaining('utf8_lines'),
      matching: find.byType(BookTile),
    );
    expect(
      find.descendant(of: plain, matching: find.byType(Image)),
      findsNothing,
    );
    expect(find.descendant(of: plain, matching: find.text('P')), findsOne);
    await closeApp(tester);
  });

  testWidgets('several files: a summary with duplicates and failures', (
    tester,
  ) async {
    final txt = 'test/fixtures/txt/utf8_lines.txt';
    final paths = picked([txt, txt]);
    final bad = File('${temp.path}/x.bin')
      ..writeAsBytesSync(List.filled(500, 0));
    await pumpApp(tester, () async => [...paths, bad.path]);

    await addBooks(tester);

    expect(find.byType(BookTile), findsOneWidget);
    expect(
      find.text(
        'Добавлено книг: 1, уже были в библиотеке: 1, не удалось добавить: 1',
      ),
      findsOneWidget,
    );
    await closeApp(tester);
  });
}
