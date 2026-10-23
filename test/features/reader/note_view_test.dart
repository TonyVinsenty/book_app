import 'dart:io';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/features/reader/note_view.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = PageStyle(
    fontFamily: 'Literata',
    color: Color(0xFF000000),
    noteColor: Color(0xFF9A6B43),
  );

  /// A paragraph with label [label] of note [id] at its end.
  ParagraphBlock withLabel(String text, String label, String id) =>
      ParagraphBlock(
        text: '$text$label',
        spans: [
          Span(
            text.length,
            text.length + label.length,
            SpanKind.noteRef,
            noteId: id,
          ),
        ],
      );

  final book = NoteBook(
    notes: {
      'short': Note(
        label: '1',
        blocks: [withLabel('Короткая сноска, в ней ещё одна', '2', 'inner')],
      ),
      'inner': const Note(
        label: '2',
        blocks: [ParagraphBlock(text: 'Сноска в сноске.')],
      ),
      'withLong': Note(
        label: '3',
        blocks: [withLabel('Здесь длинная', '4', 'long')],
      ),
      'long': Note(
        label: '4',
        blocks: [
          for (var i = 0; i < 60; i++)
            ParagraphBlock(text: List.filled(30, 'слово').join(' ')),
        ],
      ),
      'bare': const Note(blocks: [ParagraphBlock(text: 'Без метки.')]),
    },
    style: style,
    side: 16,
    imagesDir: Directory.systemTemp,
  );

  Future<void> open(WidgetTester tester, String id) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(ReadingPalette.paper, night: false),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => openNote(context, book, id),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Taps the label [label] inside the shown note (drawn in brackets).
  Future<void> tapLabel(WidgetTester tester, String label) async {
    await tester.tap(find.text('[$label]').last);
    await tester.pumpAndSettle();
  }

  test('a note is short when it takes no more than half a screen', () {
    const screen = Size(400, 800);
    expect(isShortNote(book.notes['short']!, book, screen), isTrue);
    expect(isShortNote(book.notes['long']!, book, screen), isFalse);
    final height = noteHeight(book.notes['long']!, book, 368);
    expect(
      isShortNote(book.notes['long']!, book, Size(400, height * 2)),
      isTrue,
    );
  });

  testWidgets('a short note opens in a panel; a note inside it — in the same '
      'panel with a back arrow', (tester) async {
    await open(tester, 'short');
    expect(find.byType(NoteSheet), findsOneWidget);
    expect(find.text('Сноска 1'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    await tapLabel(tester, '2');
    expect(find.text('Сноска 2'), findsOneWidget);
    expect(find.text('Сноска в сноске.', findRichText: true), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    // Back goes a step back, then closes the panel.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Сноска 1'), findsOneWidget);
    await tapLabel(tester, '2');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Сноска 1'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NoteSheet), findsNothing);
  });

  testWidgets('a long note opens as a screen, from a panel too; back returns '
      'step by step', (tester) async {
    await open(tester, 'long');
    expect(find.byType(NoteScreen), findsOneWidget);
    expect(find.text('Сноска 4'), findsOneWidget);
    await tester.drag(find.byType(Scrollable), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(NoteScreen), findsNothing);

    await open(tester, 'withLong');
    expect(find.byType(NoteSheet), findsOneWidget);
    await tapLabel(tester, '4');
    expect(find.byType(NoteScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(NoteScreen), findsNothing);
    expect(find.text('Сноска 3'), findsOneWidget, reason: 'the panel stays');
  });

  testWidgets('a note without a label of its own', (tester) async {
    await open(tester, 'bare');
    expect(find.text('Сноска'), findsOneWidget);
  });
}
