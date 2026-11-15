import 'dart:async';

import 'package:book_app/data/settings_repository.dart';
import 'package:book_app/features/reader/tts_playback.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

class TtsPanel extends StatefulWidget {
  const TtsPanel({
    super.key,
    required this.settings,
    required this.playback,
    required this.start,
    required this.pageWord,
    required this.savedWord,
    required this.requestedWord,
    required this.wordCount,
    required this.sentenceStart,
    required this.paragraphStart,
    required this.sentenceText,
  });

  final SettingsRepository settings;
  final TtsPlayback playback;
  final Future<void> Function(Uri server, String token, int word, int speed)
  start;
  final int pageWord;
  final int? savedWord;
  final int? requestedWord;
  final int wordCount;
  final int Function(int word) sentenceStart;
  final int Function(int word) paragraphStart;
  final String Function(int word) sentenceText;

  @override
  State<TtsPanel> createState() => _TtsPanelState();
}

class _TtsPanelState extends State<TtsPanel> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  bool _saving = false;
  bool _ready = false;
  bool _editConnection = false;
  String? _error;
  int _speed = 100;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSettings());
  }

  Future<void> _loadSettings() async {
    final address = await widget.settings.get(SettingKeys.ttsServerUrl);
    final token = await widget.settings.get(SettingKeys.ttsServerToken);
    final speed = await widget.settings.get(SettingKeys.ttsSpeed);
    if (!mounted) return;
    _url.text = address ?? '';
    _token.text = token ?? '';
    _editConnection = address == null || token == null;
    _speed = int.tryParse(speed ?? '') ?? 100;
    setState(() => _ready = true);
  }

  Future<void> _start([int? word]) async {
    final l10n = AppLocalizations.of(context);
    final address = _url.text.trim();
    final token = _token.text.trim();
    final uri = Uri.tryParse(address);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        token.isEmpty) {
      setState(() => _error = l10n.ttsInvalidConnection);
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await widget.settings.setAll({
        SettingKeys.ttsServerUrl: address,
        SettingKeys.ttsServerToken: token,
      });
      unawaited(
        widget.start(
          uri,
          token,
          word ?? widget.savedWord ?? widget.pageWord,
          _speed,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = l10n.ttsFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeSpeed(int delta) async {
    final speed = (_speed + delta).clamp(70, 130);
    if (speed == _speed) return;
    setState(() => _speed = speed);
    await widget.settings.set(SettingKeys.ttsSpeed, '$speed');
    await widget.playback.setSpeechSpeed(speed);
  }

  void _back({required bool paragraph}) {
    final current =
        widget.playback.currentWord ?? widget.savedWord ?? widget.pageWord;
    final start = paragraph
        ? widget.paragraphStart(current)
        : widget.sentenceStart(current);
    final previous = start <= 0 ? 0 : start - 1;
    final word = paragraph
        ? widget.paragraphStart(previous)
        : widget.sentenceStart(previous);
    unawaited(_start(word));
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
    return ValueListenableBuilder(
      valueListenable: widget.playback.status,
      builder: (context, status, _) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.ttsTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context)
                        .closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (!_editConnection)
                TextButton(
                  onPressed: () => setState(() => _editConnection = true),
                  child: Text(l10n.ttsConnection),
                ),
              if (_editConnection)
                TextField(
                  enabled: _ready && !_saving,
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.ttsAddress,
                    hintText: 'https://example.modal.run',
                    border: const OutlineInputBorder(),
                  ),
                ),
              if (_editConnection) const SizedBox(height: 12),
              if (_editConnection)
                TextField(
                  enabled: _ready && !_saving,
                  controller: _token,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.ttsToken,
                    border: const OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 12),
              if (widget.savedWord != null && !status.active)
                Text(
                  l10n.ttsSavedPlace(widget.sentenceText(widget.savedWord!)),
                ),
              if (_saving || status.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null || status.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error ?? '${l10n.ttsFailed} ${status.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (status.page > 0) Text(l10n.ttsPagesPlayed(status.page)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: status.active
                        ? (status.playing
                              ? widget.playback.pause
                              : widget.playback.play)
                        : (_ready && !_saving
                              ? () => _start(widget.requestedWord)
                              : null),
                    icon: Icon(status.playing ? Icons.pause : Icons.play_arrow),
                    label: Text(status.playing ? l10n.ttsPause : l10n.ttsPlay),
                  ),
                  if (status.active)
                    TextButton(
                      onPressed: widget.playback.stop,
                      child: Text(l10n.ttsStop),
                    ),
                  if (status.active)
                    TextButton(
                      onPressed: _saving ? null : () => _start(widget.pageWord),
                      child: Text(l10n.ttsPlayFromPage),
                    ),
                ],
              ),
              if (status.active)
                Row(
                  children: [
                    IconButton(
                      tooltip: l10n.ttsBackParagraph,
                      onPressed: () => _back(paragraph: true),
                      icon: const Icon(Icons.keyboard_double_arrow_left),
                    ),
                    IconButton(
                      tooltip: l10n.ttsBackSentence,
                      onPressed: () => _back(paragraph: false),
                      icon: const Icon(Icons.keyboard_arrow_left),
                    ),
                    IconButton(
                      tooltip: l10n.ttsSlower,
                      onPressed: _speed > 70 ? () => _changeSpeed(-10) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$_speed%'),
                    IconButton(
                      tooltip: l10n.ttsFaster,
                      onPressed: _speed < 130 ? () => _changeSpeed(10) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TtsMiniPlayer extends StatelessWidget {
  const TtsMiniPlayer({
    super.key,
    required this.playback,
    required this.open,
    required this.owner,
  });

  final TtsPlayback playback;
  final VoidCallback open;
  final Object owner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: playback.status,
      builder: (context, status, _) {
        if (!playback.belongsTo(owner)) return const SizedBox.shrink();
        return Material(
          elevation: 2,
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l10n.ttsTitle,
                onPressed: open,
                icon: Icon(
                  status.error == null ? Icons.headphones : Icons.error_outline,
                ),
              ),
              if (status.active) ...[
                IconButton(
                  tooltip: status.playing ? l10n.ttsPause : l10n.ttsPlay,
                  onPressed: status.playing ? playback.pause : playback.play,
                  icon: Icon(status.playing ? Icons.pause : Icons.play_arrow),
                ),
                IconButton(
                  tooltip: l10n.ttsStop,
                  onPressed: playback.stop,
                  icon: const Icon(Icons.stop),
                ),
              ],
              if (!status.active && status.error != null)
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: playback.stop,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        );
      },
    );
  }
}
