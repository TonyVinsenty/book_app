import 'package:book_app/data/collection_repository.dart';
import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/folders/folder_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FolderRepository repo;
  var clock = DateTime(2026, 10, 21, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clock = DateTime(2026, 10, 21, 12);
    repo = FolderRepository(db, now: () => clock);
  });

  tearDown(() => db.close());

  const a = FolderEntry(key: 'a.fb2', size: 10, modified: 1000);
  const b = FolderEntry(key: 'sub/b.epub', size: 20, modified: 0);

  test('the own folder is made once and comes first', () async {
    final picked = await repo.addPicked(ref: 'uri://books', name: 'Книги');
    final own = await repo.ensureOwn();
    expect(await repo.ensureOwn(), own);
    expect([for (final f in await repo.folders()) f.id], [own.id, picked.id]);
    expect(own.kind, FolderKind.own);
    expect(own.ref, isNull);
    expect(picked.lost, isFalse);
  });

  test('the own folder cannot be disconnected', () async {
    final own = await repo.ensureOwn();
    expect(() => repo.remove(own.id), throwsA(isA<OwnFolderException>()));
    expect(await repo.folders(), hasLength(1));
  });

  test('disconnecting forgets the seen files of that folder only', () async {
    final own = await repo.ensureOwn();
    final picked = await repo.addPicked(ref: 'r', name: 'Книги');
    await repo.remember(own.id, a);
    await repo.remember(picked.id, a);
    await repo.remember(picked.id, b);

    await repo.remove(picked.id);

    expect(await repo.folders(), [own]);
    expect((await repo.knownFiles(own.id)).keys, ['a.fb2']);
    expect(await db.select(db.folderFiles).get(), hasLength(1));
  });

  test('remember overwrites a changed file, forget drops keys', () async {
    final own = await repo.ensureOwn();
    await repo.remember(own.id, a);
    await repo.remember(own.id, b);
    clock = clock.add(const Duration(hours: 1));
    await repo.remember(
      own.id,
      const FolderEntry(key: 'a.fb2', size: 11, modified: 2000),
    );

    var known = await repo.knownFiles(own.id);
    expect(known['a.fb2']!.size, 11);
    expect(known['a.fb2']!.modified, 2000);
    expect(known['a.fb2']!.seenAt, clock);

    await repo.forget(own.id, ['sub/b.epub', 'missing']);
    await repo.forget(own.id, const []);
    known = await repo.knownFiles(own.id);
    expect(known.keys, ['a.fb2']);
  });

  test('lost access, a new handle and the scan mark', () async {
    final f = await repo.addPicked(ref: 'old', name: 'Книги');
    await repo.markLost(f.id);
    expect((await repo.folders()).single.lost, isTrue);

    await repo.setRef(f.id, 'new');
    var row = (await repo.folders()).single;
    expect(row.lost, isFalse);
    expect(row.ref, 'new');

    await repo.markScanned(f.id, tooBig: true);
    row = (await repo.folders()).single;
    expect(row.scannedAt, clock);
    expect(row.tooBig, isTrue);
    await repo.markScanned(f.id);
    expect((await repo.folders()).single.tooBig, isFalse);
  });

  test('deleting the collection unlinks the folder, keeps it', () async {
    final collections = CollectionRepository(db, now: () => clock);
    final c = await collections.create('Из папки');
    final f = await repo.addPicked(ref: 'r', name: 'Книги', collectionId: c.id);
    expect(f.collectionId, c.id);

    await collections.delete(c.id);

    final row = (await repo.folders()).single;
    expect(row.id, f.id);
    expect(row.collectionId, isNull);
  });

  test('watchFolders sends changes', () async {
    final seen = <int>[];
    final sub = repo.watchFolders().listen((rows) => seen.add(rows.length));
    await pumpEventQueue();
    await repo.ensureOwn();
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, [0, 1]);
  });
}
