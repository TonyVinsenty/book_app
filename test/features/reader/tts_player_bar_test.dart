import 'package:book_app/features/reader/tts_panel.dart';
import 'package:book_app/features/reader/tts_playback.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('speech controls fit a narrow phone and name voice speed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final playback = TtsPlayback();
    playback.status.value = (
      active: true,
      playing: true,
      loading: false,
      page: 1,
      word: 0,
      endWord: 3,
      speed: 100,
      error: null,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: Text('Книга')),
              TtsPlayerBar(
                playback: playback,
                backParagraph: () {},
                backSentence: () {},
                forwardSentence: () {},
                changeSpeed: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Скорость голоса 100%'), findsOneWidget);
    expect(find.byTooltip('Предыдущий абзац'), findsOneWidget);
    expect(find.byTooltip('Следующее предложение'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
