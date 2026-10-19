import 'dart:io';

import 'package:book_app/data/providers.dart';
import 'package:book_app/features/library/library_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/fake_importer.dart';

void main() {
  late Directory temp;
  late FakeImporter importer;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('library_');
    importer = FakeImporter()..hold = true;
  });
  tearDown(() => temp.deleteSync(recursive: true));

  /// Lets real async work (file deletion) run.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  Future<void> pumpLibrary(WidgetTester tester, List<String> picked) async {
    final paths = [
      for (final name in picked)
        (File('${temp.path}/$name')..writeAsStringSync('x')).path,
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          booksProvider.overrideWithValue(const AsyncData([])),
          bookImporterProvider.overrideWithValue(importer),
          pickBooksProvider.overrideWithValue(() async => paths),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LibraryScreen(),
        ),
      ),
    );
  }

  Future<void> release(WidgetTester tester) async {
    await tester.runAsync(importer.release);
    await settle(tester);
  }

  testWidgets('shows progress, then a summary with details', (tester) async {
    await pumpLibrary(tester, ['a.txt', 'dup.txt', 'bad.txt']);
    await tester.tap(find.text('Добавить книгу'));
    await settle(tester);

    expect(find.text('Добавляется 1 из 3: a.txt'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // The picker waits until the queue is done.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(FloatingActionButton), findsNothing);

    await release(tester);
    expect(find.text('Добавляется 2 из 3: dup.txt'), findsOneWidget);
    await release(tester);
    await release(tester);
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(
      find.text(
        'Добавлено книг: 1, уже были в библиотеке: 1, '
        'не удалось добавить: 1',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Подробнее'));
    await tester.pumpAndSettle();
    expect(find.text('Добавление книг'), findsOneWidget);
    expect(find.text('Добавлена'), findsOneWidget);
    expect(find.text('Уже была в библиотеке'), findsOneWidget);
    expect(find.text('Файл повреждён'), findsOneWidget);
    expect(find.text('bad.txt'), findsOneWidget);
  });

  testWidgets('one file: its own message, no details', (tester) async {
    await pumpLibrary(tester, ['bad.fb2']);
    await tester.tap(find.text('Добавить книгу'));
    await settle(tester);
    await release(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Файл повреждён, книгу не удалось прочитать: bad.fb2'),
      findsOneWidget,
    );
    expect(find.text('Подробнее'), findsNothing);
  });

  testWidgets('a cancelled pick does nothing', (tester) async {
    await pumpLibrary(tester, []);
    await tester.tap(find.text('Добавить книгу'));
    await settle(tester);

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
