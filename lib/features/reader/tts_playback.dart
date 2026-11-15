import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

typedef SpeechPage = ({int firstWord, int endWord, String text});
typedef SpeechStatus = ({
  bool active,
  bool playing,
  bool loading,
  int page,
  int? word,
  int? endWord,
  int speed,
  Object? error,
});

final ttsPlaybackProvider = Provider<TtsPlayback>((ref) => TtsPlayback());

class TtsPlayback extends BaseAudioHandler {
  static Future<TtsPlayback> initialize() => AudioService.init(
    builder: TtsPlayback.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.tonyvinsenty.bookapp.playback',
      androidNotificationChannelName: 'Verso',
      androidStopForegroundOnPause: false,
    ),
  );

  final status = ValueNotifier<SpeechStatus>((
    active: false,
    playing: false,
    loading: false,
    page: 0,
    word: null,
    endWord: null,
    speed: 100,
    error: null,
  ));
  _SpeechRun? _run;
  Object? _owner;
  Future<void> Function(int word)? _savePosition;

  bool belongsTo(Object owner) => identical(_owner, owner);

  Future<void> start({
    required Object owner,
    required Uri server,
    required String token,
    required String voice,
    required String title,
    required String stopLabel,
    required int firstWord,
    required int speed,
    required Future<void> Function(int word) savePosition,
    required SpeechPage? Function(int word) pageAt,
    required void Function(int word) onPage,
  }) async {
    if (_run != null) unawaited(stop());
    _savePosition = savePosition;
    final run = _SpeechRun(
      server: server,
      token: token,
      voice: voice,
      stopLabel: stopLabel,
      nextWord: firstWord,
      speed: speed,
      pageAt: pageAt,
      onPage: onPage,
    );
    _owner = owner;
    _run = run;
    mediaItem.add(MediaItem(id: 'verso-speech', title: title, artist: 'Verso'));
    _publish(run);
    run.subscriptions.addAll([
      run.player.playerStateStream.listen((_) {
        if (run.playerRequested) run.playing = run.player.playing;
        _update(run);
      }),
      run.player.currentIndexStream.listen((_) => _update(run)),
      run.player.positionStream.listen((_) => _update(run)),
      run.player.errorStream.listen((error) {
        if (_run == run) unawaited(_end(error: error));
      }),
    ]);
    run.job = _prepare(run);
    await run.job;
  }

  Future<void> _prepare(_SpeechRun run) async {
    try {
      final session = await AudioSession.instance;
      if (_run != run) return;
      await session.configure(const AudioSessionConfiguration.speech());
      if (_run != run) return;
      run.directory = await (await getTemporaryDirectory()).createTemp(
        'verso-speech-',
      );
      if (_run != run) return;
      await run.player.setSpeed(run.speed / 100);
      await _fill(run, 3);
    } catch (error) {
      if (_run == run) unawaited(_end(error: error));
    }
  }

  Future<void> _fill(_SpeechRun run, int count) async {
    run.filling = true;
    try {
      // Every refill starts on the second prepared page or later. Drop
      // finished sources before adding more, keeping the cache bounded.
      while ((run.player.currentIndex ?? 0) > 0) {
        final oldest = run.pages.first;
        await run.player.removeAudioSourceAt(0);
        if (_run != run) return;
        run.pages.removeAt(0);
        await run.deleteFile(oldest.index);
      }
      for (var added = 0; added < count && _run == run; added++) {
        final page = run.pageAt(run.nextWord);
        if (page == null) {
          run.exhausted = true;
          break;
        }
        final index = run.prepared;
        final file = await run.download(page.text, index);
        if (_run != run) return;
        final queued = (
          index: index,
          word: page.firstWord,
          endWord: page.endWord,
        );
        final source = AudioSource.file(file.path, tag: queued);
        final player = run.player;
        final first = run.pages.isEmpty;
        final completed = player.processingState == ProcessingState.completed;
        final previous = player.currentIndex;
        final next = run.pages.length;
        run.nextWord = page.endWord;
        run.prepared++;
        run.pages.add(queued);
        if (first) {
          await player.setAudioSource(source);
          if (_run == run && run.playing) _play(run);
        } else {
          await player.addAudioSource(source);
          if (_run == run &&
              player.currentIndex == previous &&
              (completed ||
                  player.processingState == ProcessingState.completed)) {
            await player.seek(Duration.zero, index: next);
            if (_run == run && run.playing) _play(run);
          }
        }
      }
    } catch (error) {
      if (_run == run) {
        run.error = error;
        run.exhausted = true;
      }
    } finally {
      run.filling = false;
      _update(run);
    }
  }

  void _update(_SpeechRun run) {
    if (_run != run) return;
    final player = run.player;
    // The source tag keeps its absolute position when the playlist is trimmed.
    if (player.sequenceState.currentSource?.tag case final _QueuedSpeech page) {
      if (run.current != page.index &&
          player.playing &&
          player.processingState == ProcessingState.ready) {
        run.current = page.index;
        run.currentWord = page.word;
        run.currentEndWord = page.endWord;
        unawaited(_savePosition?.call(page.word) ?? Future<void>.value());
        run.onPage(page.word);
      }
    }
    final completed = player.processingState == ProcessingState.completed;
    if (run.exhausted &&
        !run.filling &&
        (completed ||
            run.pages.isEmpty ||
            player.processingState == ProcessingState.idle)) {
      unawaited(_end(error: run.error));
      return;
    }
    if (!run.exhausted && !run.filling && run.playing) {
      final duration = player.duration;
      final nearEnd =
          duration != null &&
          player.position.inMicroseconds >= duration.inMicroseconds * .8;
      if (completed || (run.current >= run.refillAt && nearEnd)) {
        run.refillAt = run.prepared;
        run.job = _fill(run, 2);
      }
    }
    _publish(run);
  }

  void _publish(_SpeechRun run) {
    final player = run.player;
    final waiting =
        run.current < 0 ||
        player.processingState == ProcessingState.loading ||
        player.processingState == ProcessingState.buffering ||
        player.processingState == ProcessingState.completed;
    status.value = (
      active: true,
      playing: run.playing,
      loading: waiting,
      page: run.current + 1,
      word: run.currentWord,
      endWord: run.currentEndWord,
      speed: run.speed,
      error: run.error,
    );
    final processingState = waiting
        ? AudioProcessingState.buffering
        : AudioProcessingState.ready;
    final last = playbackState.value;
    if (last.processingState == processingState &&
        last.playing == run.playing) {
      return;
    }
    playbackState.add(
      PlaybackState(
        controls: [
          if (run.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop.copyWith(label: run.stopLabel),
        ],
        androidCompactActionIndices: const [0, 1],
        playing: run.playing,
        processingState: processingState,
      ),
    );
  }

  void _play(_SpeechRun run) {
    run.playerRequested = true;
    unawaited(
      run.player.play().catchError((Object error) {
        if (_run == run && run.playing) unawaited(_end(error: error));
      }),
    );
  }

  @override
  Future<void> play() async {
    final run = _run;
    if (run == null || run.playing) return;
    run.playing = true;
    if (run.pages.isNotEmpty) _play(run);
    _update(run);
  }

  @override
  Future<void> pause() async {
    final run = _run;
    if (run == null) return;
    run.playing = false;
    _publish(run);
    await run.player.pause();
  }

  @override
  Future<void> stop() => _end();

  Future<void> setSpeechSpeed(int speed) async {
    final run = _run;
    if (run == null || speed < 70 || speed > 130 || speed % 10 != 0) return;
    run.speed = speed;
    await run.player.setSpeed(speed / 100);
    _publish(run);
  }

  int? get currentWord => _run?.currentWord;

  Future<void> _end({Object? error}) async {
    final run = _run;
    _run = null;
    if (error == null) _owner = null;
    playbackState.add(PlaybackState());
    mediaItem.add(null);
    status.value = (
      active: false,
      playing: false,
      loading: false,
      page: error == null ? 0 : status.value.page,
      word: error == null ? null : status.value.word,
      endWord: error == null ? null : status.value.endWord,
      speed: status.value.speed,
      error: error,
    );
    if (run == null) return;
    run.client.close(force: true);
    for (final subscription in run.subscriptions) {
      await subscription.cancel();
    }
    await run.player.dispose();
    await run.job;
    try {
      await run.directory?.delete(recursive: true);
    } on FileSystemException {
      // A temporary cache may already have been purged by the OS.
    }
  }
}

typedef _QueuedSpeech = ({int index, int word, int endWord});

class _SpeechRun {
  _SpeechRun({
    required this.server,
    required this.token,
    required this.voice,
    required this.stopLabel,
    required this.nextWord,
    required this.speed,
    required this.pageAt,
    required this.onPage,
  });

  final Uri server;
  final String token;
  final String voice;
  final String stopLabel;
  final SpeechPage? Function(int word) pageAt;
  final void Function(int word) onPage;
  final player = AudioPlayer();
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final subscriptions = <StreamSubscription<dynamic>>[];
  final pages = <_QueuedSpeech>[];
  Directory? directory;
  Future<void>? job;
  int nextWord;
  int speed;
  int? currentWord;
  int? currentEndWord;
  int prepared = 0;
  int refillAt = 1;
  int current = -1;
  bool playing = true;
  bool playerRequested = false;
  bool filling = false;
  bool exhausted = false;
  Object? error;

  File _fileAt(int index) => File('${directory!.path}/$index.wav');

  Future<void> deleteFile(int index) async {
    try {
      await _fileAt(index).delete();
    } on FileSystemException {
      // Cache cleanup must not interrupt playback.
    }
  }

  Future<File> download(String text, int index) async {
    final request = await client
        .postUrl(server.resolve('/v1/synthesize'))
        .timeout(const Duration(seconds: 15));
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.headers.set('X-TTS-Token', token);
    final body = utf8.encode(jsonEncode({'text': text, 'voice': voice}));
    request.contentLength = body.length;
    request.add(body);
    final timeout = const Duration(seconds: 90);
    final response = await request.close().timeout(timeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}');
    }
    final file = _fileAt(index);
    final sink = file.openWrite();
    try {
      await sink.addStream(response.timeout(timeout));
    } finally {
      await sink.close();
    }
    return file;
  }
}
