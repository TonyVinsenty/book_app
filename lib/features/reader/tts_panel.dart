import 'dart:async';

import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/features/reader/tts_connection.dart';
import 'package:book_app/features/reader/tts_playback.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

const ttsVoices = ['eugene', 'aidar', 'xenia', 'baya'];

class TtsPanel extends StatefulWidget {
  const TtsPanel({
    super.key,
    required this.settings,
    required this.playback,
    required this.start,
    required this.pageWord,
    required this.savedWord,
    required this.requestedWord,
    required this.choosePlace,
    required this.choosingPlace,
  });

  final SettingsRepository settings;
  final TtsPlayback playback;
  final Future<void> Function(
    Uri server,
    String token,
    String voice,
    int word,
    int speed,
  )
  start;
  final int pageWord;
  final int? savedWord;
  final int? requestedWord;
  final VoidCallback choosePlace;
  final bool choosingPlace;

  @override
  State<TtsPanel> createState() => _TtsPanelState();
}

class _TtsPanelState extends State<TtsPanel> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  bool _ready = false;
  String _voice = 'eugene';
  int _speed = 100;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final connection = await loadTtsConnection(widget.settings);
    final voice = await widget.settings.get(SettingKeys.ttsVoice);
    final speed = await widget.settings.get(SettingKeys.ttsSpeed);
    if (!mounted) return;
    _url.text = connection.url;
    _token.text = connection.token;
    _voice = ttsVoices.contains(voice) ? voice! : 'eugene';
    _speed = int.tryParse(speed ?? '') ?? 100;
    setState(() => _ready = true);
    if (connection.token.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_editConnection());
      });
    }
  }

  Future<void> _editConnection() async {
    final l10n = AppLocalizations.of(context);
    final urlField = TextEditingController(text: _url.text);
    final tokenField = TextEditingController(text: _token.text);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.ttsConnection),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlField,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(labelText: l10n.ttsAddress),
            ),
            TextField(
              controller: tokenField,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.ttsToken),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    final address = urlField.text.trim();
    final token = tokenField.text.trim();
    urlField.dispose();
    tokenField.dispose();
    if (!mounted || saved != true) return;
    final uri = Uri.tryParse(address);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        token.isEmpty) {
      setState(() => _error = l10n.ttsInvalidConnection);
      return;
    }
    await widget.settings.setAll({
      SettingKeys.ttsServerUrl: uri.toString(),
      SettingKeys.ttsServerToken: token,
      SettingKeys.ttsConnectionOverride: 'true',
    });
    if (mounted) {
      _url.text = uri.toString();
      _token.text = token;
      setState(() => _error = null);
    }
  }

  void _start() {
    final l10n = AppLocalizations.of(context);
    final uri = Uri.tryParse(_url.text.trim());
    final token = _token.text.trim();
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        token.isEmpty) {
      unawaited(_editConnection());
      setState(() => _error = l10n.ttsInvalidConnection);
      return;
    }
    setState(() => _error = null);
    unawaited(
      widget.start(
        uri,
        token,
        _voice,
        widget.requestedWord ?? widget.savedWord ?? widget.pageWord,
        _speed,
      ),
    );
  }

  Future<void> _selectVoice(String voice) async {
    setState(() => _voice = voice);
    await widget.settings.set(SettingKeys.ttsVoice, voice);
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final names = [
      l10n.ttsVoiceEugene,
      l10n.ttsVoiceAidar,
      l10n.ttsVoiceXenia,
      l10n.ttsVoiceBaya,
    ];
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.ttsVoice,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < ttsVoices.length; i++) ...[
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: _voice == ttsVoices[i]
                            ? FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: _ready
                                    ? () =>
                                          unawaited(_selectVoice(ttsVoices[i]))
                                    : null,
                                child: Text(
                                  names[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              )
                            : OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                onPressed: _ready
                                    ? () =>
                                          unawaited(_selectVoice(ttsVoices[i]))
                                    : null,
                                child: Text(
                                  names[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                      ),
                    ),
                    if (i < ttsVoices.length - 1) const SizedBox(width: 5),
                  ],
                ],
              ),
              const SizedBox(height: 9),
              if (widget.choosingPlace)
                Text(l10n.ttsChoosePlaceHint, textAlign: TextAlign.center)
              else
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _ready ? _start : null,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l10n.ttsContinue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.choosePlace,
                        child: Text(
                          l10n.ttsChoosePlace,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              if (_error != null || widget.playback.status.value.error != null)
                Text(
                  _error ?? l10n.ttsFailed,
                  style: TextStyle(color: colors.error),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: l10n.ttsConnection,
                  onPressed: _ready ? () => unawaited(_editConnection()) : null,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TtsPlayerBar extends StatelessWidget {
  const TtsPlayerBar({
    super.key,
    required this.playback,
    required this.backParagraph,
    required this.backSentence,
    required this.forwardSentence,
    required this.changeSpeed,
  });

  final TtsPlayback playback;
  final VoidCallback backParagraph;
  final VoidCallback backSentence;
  final VoidCallback forwardSentence;
  final void Function(int delta) changeSpeed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: playback.status,
      builder: (context, status, _) => Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${l10n.ttsSpeechSpeed}  ${status.speed}%',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _button(
                              Icons.keyboard_double_arrow_left,
                              l10n.ttsBackParagraph,
                              backParagraph,
                              width: 42,
                            ),
                            _button(
                              Icons.keyboard_arrow_left,
                              l10n.ttsBackSentence,
                              backSentence,
                              width: 42,
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: IconButton.filled(
                          tooltip: status.playing
                              ? l10n.ttsPause
                              : l10n.ttsPlay,
                          onPressed: status.playing
                              ? playback.pause
                              : playback.play,
                          icon: Icon(
                            status.playing ? Icons.pause : Icons.play_arrow,
                            size: 28,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _button(
                              Icons.keyboard_arrow_right,
                              l10n.ttsNextSentence,
                              forwardSentence,
                              width: 40,
                            ),
                            const SizedBox(
                              height: 32,
                              child: VerticalDivider(width: 6),
                            ),
                            _button(
                              Icons.remove,
                              l10n.ttsSlower,
                              status.speed > 70 ? () => changeSpeed(-10) : null,
                              width: 36,
                            ),
                            _button(
                              Icons.add,
                              l10n.ttsFaster,
                              status.speed < 130 ? () => changeSpeed(10) : null,
                              width: 36,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed, {
    required double width,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 29),
    constraints: BoxConstraints.tightFor(width: width, height: 48),
    padding: EdgeInsets.zero,
  );
}
