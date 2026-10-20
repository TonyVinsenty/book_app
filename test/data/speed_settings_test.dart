import 'package:book_app/data/db/app_database.dart';
import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/data/speed_settings.dart';
import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/speed/timing.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository store;
  late SpeedSettings speed;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = SettingsRepository(db);
    speed = SpeedSettings(store);
  });

  tearDown(() => db.close());

  test('the saved mode is read back; none → word', () async {
    expect(await speed.mode(pro: true), SpeedMode.word);
    await speed.setMode(SpeedMode.guide);
    expect(await speed.mode(pro: true), SpeedMode.guide);
    expect(await store.get(SettingKeys.speedMode), 'guide');
  });

  test('broken mode → word; without Pro → word', () async {
    await store.set(SettingKeys.speedMode, 'karaoke');
    expect(await speed.mode(pro: true), SpeedMode.word);
    await speed.setMode(SpeedMode.phrase);
    expect(await speed.mode(pro: false), SpeedMode.word);
  });

  test('each mode has its own pace', () async {
    expect(await speed.wordsPerMinute(SpeedMode.word), 300);
    expect(await speed.wordsPerMinute(SpeedMode.phrase), 300);
    expect(await speed.wordsPerMinute(SpeedMode.guide), 250);

    await speed.setWordsPerMinute(SpeedMode.phrase, 450);
    expect(await speed.wordsPerMinute(SpeedMode.phrase), 450);
    expect(await speed.wordsPerMinute(SpeedMode.word), 300);
  });

  test('the old word pace key is kept; broken values are limited', () async {
    await store.set('speed.wpm', '525');
    expect(await speed.wordsPerMinute(SpeedMode.word), 525);
    await store.set(SettingKeys.speedWpmGuide, '5000');
    expect(await speed.wordsPerMinute(SpeedMode.guide), SpeedLimits.max);
    await store.set(SettingKeys.speedWpmPhrase, 'fast');
    expect(await speed.wordsPerMinute(SpeedMode.phrase), 300);
  });
}
