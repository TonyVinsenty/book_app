/// What speed reading shows at a time: one word or a phrase (ADR 0004,
/// addendum for stage 10 п. 4). Steps follow one another and cover every
/// word.
abstract interface class Steps {
  /// The first word of the step [word] is in.
  int startOf(int word);

  /// The word after the step [word] is in.
  int endOf(int word);
}

/// One word at a time.
final class WordSteps implements Steps {
  const WordSteps();

  @override
  int startOf(int word) => word;

  @override
  int endOf(int word) => word + 1;
}
