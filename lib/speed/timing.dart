/// How long each word is shown in speed reading (ADR 0004 п. 4).
abstract interface class WordTiming {
  Duration durationOf(int wordIndex);
}

/// Every word for the same time: `60000 / wpm` ms. Smart pace comes later.
final class ConstantPace implements WordTiming {
  const ConstantPace(this.wordsPerMinute) : assert(wordsPerMinute > 0);

  final int wordsPerMinute;

  @override
  Duration durationOf(int wordIndex) =>
      Duration(microseconds: Duration.microsecondsPerMinute ~/ wordsPerMinute);
}

/// Speed limits and step of the − / + buttons, words per minute.
abstract final class SpeedLimits {
  static const min = 100;
  static const max = 1000;
  static const step = 25;
  static const initial = 300;

  static int clamp(int wpm) => wpm.clamp(min, max);
}
