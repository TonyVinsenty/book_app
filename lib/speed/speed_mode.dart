/// Speed reading modes (ADR 0004, addendum for stage 10 п. 1–2).
enum SpeedMode {
  /// One word at a time with the marked letter.
  word(isPro: false, initialWpm: 300),

  /// Two or three words at a time.
  phrase(isPro: true, initialWpm: 300),

  /// Leading highlight on the book page.
  guide(isPro: true, initialWpm: 250);

  const SpeedMode({required this.isPro, required this.initialWpm});

  /// Part of the future paid tier ("Pro").
  final bool isPro;

  /// Pace before the reader changes it, words per minute.
  final int initialWpm;

  /// The stored [name]; a missing or unknown one is [word].
  static SpeedMode parse(String? name) => values.asNameMap()[name] ?? word;

  /// This mode, or [word] when it needs "Pro" and [pro] is off.
  SpeedMode availableWith({required bool pro}) => !isPro || pro ? this : word;
}
