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
    required this.savedPageDelta,
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

  /// Positive when the saved speech position is behind the visible page.
  final int? savedPageDelta;
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
  int _startOption = 1;
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
      widget.start(uri, token, _voice, switch (_startOption) {
        0 => widget.savedWord ?? widget.pageWord,
        2 => widget.requestedWord ?? widget.pageWord,
        _ => widget.pageWord,
      }, _speed),
    );
  }

  Future<void> _selectVoice(String voice) async {
    setState(() => _voice = voice);
    await widget.settings.set(SettingKeys.ttsVoice, voice);
  }

  @override
  void didUpdateWidget(TtsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestedWord != null &&
        widget.requestedWord != oldWidget.requestedWord) {
      _startOption = 2;
    }
  }

  Widget _startChoice(int option, String label, {VoidCallback? onTap}) {
    final selected = _startOption == option;
    return InkWell(
      onTap: onTap ?? () => setState(() => _startOption = option),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: option == 0 ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _lastPositionLabel(AppLocalizations l10n) {
    final distance = widget.savedPageDelta;
    if (distance == null) return l10n.ttsFromLastPosition;
    final hint = distance == 0
        ? l10n.ttsOnThisPage
        : distance > 0
        ? l10n.ttsPagesEarlier(distance)
        : l10n.ttsPagesLater(-distance);
    return '${l10n.ttsFromLastPosition} · $hint';
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
              if (widget.savedWord != null)
                _startChoice(0, _lastPositionLabel(l10n)),
              _startChoice(1, l10n.ttsFromCurrentPage),
              _startChoice(
                2,
                widget.choosingPlace
                    ? l10n.ttsChoosePlaceHint
                    : widget.requestedWord == null
                    ? l10n.ttsChoosePlace
                    : l10n.ttsFromSelectedWord,
                onTap: () {
                  setState(() => _startOption = 2);
                  widget.choosePlace();
                },
              ),
              const SizedBox(height: 4),
              FilledButton.icon(
                onPressed:
                    _ready &&
                        !widget.choosingPlace &&
                        (_startOption != 2 || widget.requestedWord != null)
                    ? _start
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.ttsPlay),
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
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${l10n.ttsSpeechSpeed} ${status.speed}%',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _button(
                      Icons.remove,
                      l10n.ttsSlower,
                      status.speed > 70 ? () => changeSpeed(-10) : null,
                    ),
                    _button(
                      Icons.add,
                      l10n.ttsFaster,
                      status.speed < 130 ? () => changeSpeed(10) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _button(
                        Icons.keyboard_double_arrow_left,
                        l10n.ttsBackParagraph,
                        backParagraph,
                      ),
                    ),
                    Expanded(
                      child: _button(
                        Icons.keyboard_arrow_left,
                        l10n.ttsBackSentence,
                        backSentence,
                      ),
                    ),
                    Expanded(
                      child: Center(
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
                    ),
                    Expanded(
                      child: _button(
                        Icons.keyboard_arrow_right,
                        l10n.ttsNextSentence,
                        forwardSentence,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(IconData icon, String tooltip, VoidCallback? onPressed) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 29),
        constraints: const BoxConstraints(minWidth: 44, minHeight: 48),
        padding: EdgeInsets.zero,
      );
}
