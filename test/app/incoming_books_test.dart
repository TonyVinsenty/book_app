import 'dart:async';
import 'dart:io';

import 'package:book_app/app/app.dart';
import 'package:book_app/book/parsers/txt_parser.dart';
import 'package:book_app/book/tokenizer/tokenizer.dart';
import 'package:book_app/data/book_repository.dart';
import 'package:book_app/data/content_store.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/features/library/library_screen.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/features/speed/rsvp_screen.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../layout/sample_book.dart';

/// Books from other apps (ADR 0005, addendum 1): one file opens at once,
/// closing whatever was open; several stay in the library with a summary.
void main() {
  // Each test opens its own in-memory database.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory temp;
  late BookRepository repo;
  late int sampleId;
  late StreamController<List<String>> incoming;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('incoming_');
    incoming = StreamController<List<String>>();
  });
  tearDown(() async {
    await incoming.close();
    temp.deleteSync(recursive: true);
  });

  /// Copies of [fixtures], as the native side hands them over.
  var copies = 0;
  List<String> files(List<String> fixtures) => [
    for (final f in fixtures)
      File(f).copySync('${temp.path}/in${copies++}-${f.split('/').last}').path,
  ];

  /// Lets real async work (isolates, files, database) run until [done].
  Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(done(), isTrue);
  }

  /// The book open on top, or null in the library.
  int? openBookId(WidgetTester tester) {
    final screens = find.byType(ReaderScreen, skipOffstage: false);
    if (screens.evaluate().isEmpty) return null;
    return tester.widget<ReaderScreen>(screens.last).bookId;
  }

  /// One book open and loaded (no screens still leaving).
  bool readerShown() =>
      find.byType(ReaderScreen, skipOffstage: false).evaluate().length == 1 &&
      find.byType(ReaderView).evaluate().isNotEmpty;

  /// The app with one generated book in the library.
  Future<void> pumpApp(WidgetTester tester) async {
    // Closing a drift database under fake time hangs, so it is left open;
    // synchronous stream closing leaves no pending timer.
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = BookRepository(db, ContentStore(Directory('${temp.path}/books')));
    final content = sampleBook(paragraphs: 30);
    final source = File('${temp.path}/book.txt')..writeAsStringSync('книга');
    await tester.runAsync(() async {
      sampleId = (await repo.addBook(
        content: content,
        source: source,
        sourceName: 'book.txt',
        sourceHash: 'hash',
        parserVersion: txtParserVersion,
        wordCount: tokenize(content).length,
      )).id;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bookRepositoryProvider.overrideWithValue(repo),
          incomingFilesProvider.overrideWithValue(incoming.stream),
        ],
        child: const BookApp(),
      ),
    );
    await settleUntil(
      tester,
      () => find.byType(BookTile).evaluate().isNotEmpty || readerShown(),
    );
  }

  Future<void> openSample(WidgetTester tester) async {
    await tester.tap(find.byType(BookTile));
    await settleUntil(tester, readerShown);
  }

  Future<void> receive(WidgetTester tester, List<String> paths) async {
    incoming.add(paths);
    await tester.pump();
  }

  /// "Back" goes straight to the library.
  Future<void> expectOverLibrary(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsNothing);
    expect(find.byType(LibraryScreen), findsOneWidget);
  }

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  const fb2 = 'test/fixtures/fb2/utf8_nested.fb2';
  const txt = 'test/fixtures/txt/utf8_lines.txt';

  testWidgets('started with a file: that book opens over the library', (
    tester,
  ) async {
    final paths = files([fb2]);
    incoming.add(paths); // waits in the stream, as the native side sends it
    await pumpApp(tester);
    await settleUntil(tester, readerShown);

    expect(openBookId(tester), isNot(sampleId));
    expect(File(paths.single).existsSync(), isFalse, reason: 'copy deleted');
    await expectOverLibrary(tester);
    expect(find.byType(BookTile), findsNWidgets(2));
    await closeApp(tester);
  });

  testWidgets('a file while reading opens the new book', (tester) async {
    await pumpApp(tester);
    await openSample(tester);

    await receive(tester, files([fb2]));
    await settleUntil(
      tester,
      () => readerShown() && openBookId(tester) != sampleId,
    );

    expect(find.byType(ReaderScreen), findsOneWidget);
    await expectOverLibrary(tester);
    await closeApp(tester);
  });

  testWidgets('a file during speed reading closes it', (tester) async {
    await pumpApp(tester);
    await openSample(tester);
    final size = tester.getSize(find.byType(ReaderView));
    await tester.tapAt(Offset(size.width / 2, size.height / 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Скорочтение'));
    await settleUntil(
      tester,
      () => find.byType(RsvpScreen).evaluate().isNotEmpty,
    );

    await receive(tester, files([fb2]));
    await settleUntil(
      tester,
      () => readerShown() && openBookId(tester) != sampleId,
    );

    expect(find.byType(RsvpScreen), findsNothing);
    await expectOverLibrary(tester);
    await closeApp(tester);
  });

  testWidgets('a duplicate opens the book already there, with a hint', (
    tester,
  ) async {
    await pumpApp(tester);
    await receive(tester, files([fb2]));
    await settleUntil(tester, readerShown);
    final first = openBookId(tester);
    await expectOverLibrary(tester);
    ScaffoldMessenger.of(tester.element(find.byType(LibraryScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();

    await receive(tester, files([fb2]));
    await settleUntil(tester, readerShown);

    expect(openBookId(tester), first);
    expect(find.textContaining('уже в библиотеке'), findsOneWidget);
    await expectOverLibrary(tester);
    expect(find.byType(BookTile), findsNWidgets(2), reason: 'no copy');
    await closeApp(tester);
  });

  testWidgets('several files: the screen stays, a summary shows', (
    tester,
  ) async {
    await pumpApp(tester);
    await openSample(tester);

    await receive(tester, files([fb2, txt]));
    await settleUntil(
      tester,
      () => find.text('Добавлено книг: 2').evaluate().isNotEmpty,
    );

    expect(openBookId(tester), sampleId);
    await expectOverLibrary(tester);
    expect(find.byType(BookTile), findsNWidgets(3));
    await closeApp(tester);
  });

  testWidgets('a file that is not a book: the screen stays', (tester) async {
    await pumpApp(tester);
    await openSample(tester);
    final bad = File('${temp.path}/x.bin')
      ..writeAsBytesSync(List.filled(500, 0));

    await receive(tester, [bad.path]);
    await settleUntil(
      tester,
      () => find.textContaining('не поддерживается').evaluate().isNotEmpty,
    );

    expect(openBookId(tester), sampleId);
    await closeApp(tester);
  });

  testWidgets('a file the system could not copy: a clear message', (
    tester,
  ) async {
    await pumpApp(tester);

    await receive(tester, ['${temp.path}/in9/Книга.fb2']);
    await settleUntil(
      tester,
      () =>
          find.text('Не удалось открыть файл: Книга.fb2').evaluate().isNotEmpty,
    );

    expect(openBookId(tester), isNull);
    await closeApp(tester);
  });
}
