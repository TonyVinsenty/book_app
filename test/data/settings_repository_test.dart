import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = SettingsRepository(db);
  });

  tearDown(() => db.close());

  test('set, overwrite, remove', () async {
    expect(await settings.get('palette'), isNull);

    await settings.set('palette', 'paper');
    await settings.set('palette', 'sepia');
    await settings.set('fontSize', '18');
    expect(await settings.get('palette'), 'sepia');
    expect(await settings.get('fontSize'), '18');

    await settings.remove('palette');
    expect(await settings.get('palette'), isNull);
    expect(await settings.get('fontSize'), '18');
  });

  test('watch follows one key', () async {
    final values = <String?>[];
    final sub = settings.watch('palette').listen(values.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();

    await settings.set('palette', 'paper');
    await pumpEventQueue();
    await settings.set('palette', 'night');
    await pumpEventQueue();
    await settings.remove('palette');
    await pumpEventQueue();
    await settings.set('other', 'x');
    await pumpEventQueue();

    expect(values, [null, 'paper', 'night', null]);
  });
}
