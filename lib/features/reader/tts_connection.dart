import 'package:book_app/data/settings_repository.dart';

/// Values supplied by a private release build, never stored in source control.
const bundledTtsUrl = String.fromEnvironment(
  'VERSO_TTS_URL',
  defaultValue: 'https://tvinsenty--verso-silero-serve.us-east.modal.run',
);
const bundledTtsToken = String.fromEnvironment('VERSO_TTS_TOKEN');

typedef TtsConnection = ({String url, String token});

Future<TtsConnection> loadTtsConnection(SettingsRepository settings) async {
  final savedUrl = await settings.get(SettingKeys.ttsServerUrl) ?? '';
  final savedToken = await settings.get(SettingKeys.ttsServerToken) ?? '';
  final overridden =
      await settings.get(SettingKeys.ttsConnectionOverride) == 'true';
  if (!overridden && bundledTtsToken.isNotEmpty) {
    return (url: bundledTtsUrl, token: bundledTtsToken);
  }
  return (url: savedUrl, token: savedToken);
}
