import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/speed/timing.dart';

/// The saved speed reading mode and the pace of each mode (ADR 0004,
/// addendum for stage 10 п. 1).
final class SpeedSettings {
  const SpeedSettings(this._settings);

  final SettingsRepository _settings;

  /// The last mode used; [SpeedMode.word] when none, or when it needs "Pro"
  /// and [pro] is off.
  Future<SpeedMode> mode({required bool pro}) async => SpeedMode.parse(
    await _settings.get(SettingKeys.speedMode),
  ).availableWith(pro: pro);

  Future<void> setMode(SpeedMode mode) =>
      _settings.set(SettingKeys.speedMode, mode.name);

  /// The pace of [mode], within [SpeedLimits].
  Future<int> wordsPerMinute(SpeedMode mode) async {
    final saved = await _settings.get(SettingKeys.speedWpmOf(mode));
    return SpeedLimits.clamp(int.tryParse(saved ?? '') ?? mode.initialWpm);
  }

  Future<void> setWordsPerMinute(SpeedMode mode, int wpm) =>
      _settings.set(SettingKeys.speedWpmOf(mode), '$wpm');
}
