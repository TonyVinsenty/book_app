import 'dart:async';

import 'package:book_app/app/app_shortcuts.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_actions/quick_actions.dart';

final _day = DateTime(2026, 10, 1);

BookRow _book(int id, {int? opened, int? finished, StatusMark? mark}) =>
    BookRow(
      id: id,
      title: 'Книга $id',
      authors: const [],
      sourceFormat: SourceFormat.txt,
      sourceName: '$id.txt',
      sourceSize: 1,
      sourceHash: '$id',
      parserVersion: 1,
      wordCount: 100,
      positionWord: 0,
      positionSection: 0,
      positionBlock: 0,
      positionChar: 0,
      addedAt: _day,
      openedAt: opened == null ? null : _day.add(Duration(hours: opened)),
      touchedAt: _day,
      finishedAt: finished == null ? null : _day.add(Duration(hours: finished)),
      statusMark: mark,
    );

class _FakeQuickActions extends QuickActions {
  QuickActionHandler? handler;
  final sets = <List<ShortcutItem>>[];

  @override
  Future<void> initialize(QuickActionHandler handler) async =>
      this.handler = handler;

  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) async =>
      sets.add(items);
}

void main() {
  test('books of the menu: being read, the last opened first, two', () {
    final books = [
      _book(1, opened: 1),
      _book(2, opened: 5),
      _book(3),
      _book(4, opened: 9, finished: 10),
      _book(5, opened: 8, mark: StatusMark.abandoned),
      _book(6, opened: 3),
    ];
    expect([for (final b in shortcutBooks(books)) b.id], [2, 6]);
    expect(shortcutBooks([_book(1, opened: 1)]), hasLength(1));
    expect(shortcutBooks([_book(3)]), isEmpty);
  });

  testWidgets('the menu: the library and the books; "library" closes the '
      'screens over it', (tester) async {
    final quick = _FakeQuickActions();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          quickActionsProvider.overrideWithValue(quick),
          booksProvider.overrideWith(
            (_) => Stream.value([_book(1, opened: 1), _book(2, opened: 2)]),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          builder: (_, child) =>
              AppShortcuts(navigatorKey: navigator, child: child!),
          home: const Text('library'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(quick.sets, hasLength(1), reason: 'set once, not on each build');
    expect(
      [for (final i in quick.sets.single) (i.type, i.localizedTitle, i.icon)],
      [
        ('library', 'Библиотека', 'shortcut_library'),
        ('book:2', 'Книга 2', 'shortcut_book'),
        ('book:1', 'Книга 1', 'shortcut_book'),
      ],
    );

    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('over')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('over'), findsOneWidget);
    quick.handler!('book:x');
    await tester.pumpAndSettle();
    expect(find.text('over'), findsOneWidget, reason: 'no such book');
    quick.handler!('library');
    await tester.pumpAndSettle();
    expect(find.text('over'), findsNothing);
    expect(find.text('library'), findsOneWidget);
  });
}
