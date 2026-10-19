import 'dart:ui' show Tristate;

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/book/model/table_of_contents.dart';
import 'package:book_app/features/reader/contents_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// [count] chapters; every tenth one is a part with nested chapters.
  List<ContentsLine> lines(int count) => [
    for (var i = 0; i < count; i++)
      (
        title: i == 1 ? null : 'Глава ${i + 1}',
        level: i % 10 == 0 ? 0 : 1,
        sectionIndex: i,
      ),
  ];

  /// Pushes the table of contents; returns what it popped with.
  Future<List<int?>> pump(
    WidgetTester tester,
    List<ContentsLine> lines,
    int? current,
  ) async {
    final popped = <int?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(ReadingPalette.values.first, night: false),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => popped.add(
              await Navigator.of(context).push<int>(
                MaterialPageRoute(
                  builder: (_) =>
                      ContentsScreen(lines: lines, current: current),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return popped;
  }

  testWidgets('the current chapter of a long book is lit and in view', (
    tester,
  ) async {
    await pump(tester, lines(386), 300);
    expect(find.text('Оглавление'), findsOne);
    final current = find.text('Глава 301');
    expect(current, findsOne, reason: 'no scrolling needed');
    expect(
      tester.getSemantics(current).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(find.text('Глава 1'), findsNothing);
    // A part, then its chapters, indented and lined up.
    double x(String title) => tester.getTopLeft(find.text(title)).dx;
    expect(x('Глава 301'), lessThan(x('Глава 302')));
    expect(x('Глава 302'), x('Глава 303'));
  });

  testWidgets('a tap returns the chapter; untitled ones are numbered', (
    tester,
  ) async {
    final popped = await pump(tester, lines(12), null);
    expect(find.text('Глава 1'), findsOne, reason: 'starts at the top');
    expect(find.text('Глава 2'), findsOne, reason: 'a null title');
    expect(
      tester.getTopLeft(find.text('Глава 1')).dx,
      lessThan(tester.getTopLeft(find.text('Глава 2')).dx),
      reason: 'nested lines are indented',
    );
    await tester.tap(find.text('Глава 3'));
    await tester.pumpAndSettle();
    expect(popped, [2]);
  });

  testWidgets('the last chapters do not leave the list half empty', (
    tester,
  ) async {
    await pump(tester, lines(100), 99);
    final last = tester.getBottomLeft(find.text('Глава 100'));
    final screen = tester.getSize(find.byType(ContentsScreen));
    expect(last.dy, greaterThan(screen.height - ContentsScreen.lineHeight));
  });
}
