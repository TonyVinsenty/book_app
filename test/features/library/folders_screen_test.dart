import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/reading_palette.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/folders/folder_scanner.dart';
import 'package:book_app/data/providers.dart';
import 'package:book_app/features/library/folders_screen.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:drift/drift.dart'
    show DatabaseConnection, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late List<String> released;
  var scans = 0;

  setUp(() {
    scans = 0;
    released = [];
    // Left open: closing a drift database under fake time hangs.
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  Future<int> addFolder(
    FolderKind kind, {
    String name = '',
    String? ref,
    DateTime? scannedAt,
    bool lost = false,
    bool tooBig = false,
  }) => db
      .into(db.folders)
      .insert(
        FoldersCompanion.insert(
          kind: kind,
          name: name,
          ref: Value(ref),
          addedAt: DateTime(2026, 10, 1),
          scannedAt: Value(scannedAt),
          lost: Value(lost),
          tooBig: Value(tooBig),
        ),
      );

  Future<void> pumpFolders(
    WidgetTester tester, {
    PickFolder? pick,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pickFolderProvider.overrideWithValue(pick),
          releaseFolderProvider.overrideWithValue((ref) async {
            released.add(ref);
          }),
          scanFoldersProvider.overrideWithValue(() async {
            scans++;
            return true;
          }),
        ],
        child: MaterialApp(
          theme: buildAppTheme(
            ReadingPalette.paper,
            night: false,
          ).copyWith(platform: platform),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ru'),
          home: const FoldersScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<List<FolderRow>> rows() => db.select(db.folders).get();

  testWidgets('own folder on Android: by cable, and when looked at', (
    tester,
  ) async {
    await addFolder(FolderKind.own, scannedAt: DateTime(2026, 10, 1, 14, 5));
    await pumpFolders(tester);
    expect(find.text('Папка приложения'), findsOneWidget);
    expect(find.textContaining('Android/data/'), findsOneWidget);
    expect(find.textContaining('Просмотрена 1 окт., 14:05'), findsOneWidget);
  });

  testWidgets('own folder on iOS: in "Файлы"', (tester) async {
    await addFolder(FolderKind.own);
    await pumpFolders(tester, platform: TargetPlatform.iOS);
    expect(find.textContaining('«На iPhone» → «BookApp»'), findsOneWidget);
    expect(find.textContaining('Android/data/'), findsNothing);
  });

  testWidgets('no picker on the platform: no "Подключить папку"', (
    tester,
  ) async {
    await addFolder(FolderKind.own);
    await pumpFolders(tester);
    expect(find.text('Подключить папку'), findsNothing);
    expect(find.textContaining('Ещё не просмотрена'), findsOneWidget);
  });

  testWidgets('connects a folder and scans; the same one again — a notice', (
    tester,
  ) async {
    await pumpFolders(
      tester,
      pick: () async => (ref: 'tree:books', name: 'Книги'),
    );
    await tester.tap(find.text('Подключить папку'));
    await settle(tester);
    await settle(tester);
    expect(find.text('Книги'), findsOneWidget);
    expect(scans, 1);
    final row = (await rows()).single;
    expect(
      (row.kind, row.ref, row.name),
      (FolderKind.picked, 'tree:books', 'Книги'),
    );

    await tester.tap(find.text('Подключить папку'));
    await settle(tester);
    await settle(tester);
    expect(find.text('Эта папка уже подключена'), findsOneWidget);
    expect(await rows(), hasLength(1));
    expect(scans, 1);
  });

  testWidgets('cancelled or failed picker changes nothing', (tester) async {
    var fail = false;
    await pumpFolders(
      tester,
      pick: () async {
        if (fail) throw PlatformException(code: 'x');
        return null;
      },
    );
    await tester.tap(find.text('Подключить папку'));
    await settle(tester);
    expect(await rows(), isEmpty);

    fail = true;
    await tester.tap(find.text('Подключить папку'));
    await settle(tester);
    expect(find.text('Не удалось подключить папку'), findsOneWidget);
    expect(await rows(), isEmpty);
    expect(scans, 0);
  });

  testWidgets('no access: tap → picked again, the old handle given back', (
    tester,
  ) async {
    final id = await addFolder(
      FolderKind.picked,
      name: 'Книги',
      ref: 'tree:old',
      lost: true,
    );
    await pumpFolders(tester, pick: () async => (ref: 'tree:new', name: 'К'));
    expect(find.text('Нет доступа — подключите папку заново'), findsOneWidget);

    await tester.tap(find.text('Книги'));
    await settle(tester);
    await settle(tester);
    final row = (await rows()).single;
    expect((row.id, row.ref, row.lost), (id, 'tree:new', false));
    expect(released, ['tree:old']);
    expect(scans, 1);
    expect(find.text('Нет доступа — подключите папку заново'), findsNothing);
  });

  testWidgets('too big a folder is marked', (tester) async {
    await addFolder(FolderKind.picked, name: 'Всё', ref: 'r', tooBig: true);
    await pumpFolders(tester);
    expect(find.textContaining('больше 5000 книг'), findsOneWidget);
  });

  testWidgets('disconnect asks first; then the folder and access go', (
    tester,
  ) async {
    await addFolder(FolderKind.own);
    await addFolder(FolderKind.picked, name: 'Книги', ref: 'tree:books');
    await pumpFolders(tester);

    Future<void> disconnect(String button) async {
      await tester.tap(find.byTooltip('Ещё'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отключить'));
      await tester.pumpAndSettle();
      expect(find.text('Отключить папку «Книги»?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, button));
      await tester.pumpAndSettle();
      await settle(tester);
    }

    await disconnect('Отмена');
    expect(await rows(), hasLength(2));
    expect(released, isEmpty);

    await disconnect('Отключить');
    expect((await rows()).single.kind, FolderKind.own);
    expect(released, ['tree:books']);
    expect(find.text('Книги'), findsNothing);
  });
}
