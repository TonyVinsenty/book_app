import 'package:book_app/book/tokenizer/book_tokens.dart';

/// Words compared at a time: few enough to survive small changes of the
/// text, enough to tell repeated phrases apart.
const _run = 6;

final _notLetter = RegExp(r'[^\p{L}]', unicode: true);

/// Word of [fresh] (a new parse of the same book) where reading of [old]
/// at [oldWord] goes on: the same run of words nearest to where the word
/// should be by proportion. Null when no run around [oldWord] is found.
///
/// Anchors can't do this: a new parser may move sections and blocks
/// (covers, pictures, merged parts) and add words (link text).
int? relocateWord(BookTokens old, int oldWord, BookTokens fresh) {
  if (old.isEmpty || fresh.isEmpty) return null;
  final len = old.length < _run ? old.length : _run;
  final from = oldWord.clamp(0, old.length - 1);
  final estimate = old.length == fresh.length
      ? from
      : (from * fresh.length / old.length).round();
  final keys = [for (var i = 0; i < fresh.length; i++) _key(fresh, i)];
  // The run from the word itself first, then the runs around it.
  for (final shift in const [0, -_run, _run, -2 * _run, 2 * _run]) {
    final start = (from + shift).clamp(0, old.length - len);
    final run = [for (var j = 0; j < len; j++) _key(old, start + j)];
    if (run.every((k) => k.isEmpty)) continue;
    int? best;
    for (var i = 0; i + len <= keys.length; i++) {
      if (keys[i] != run[0]) continue;
      var j = 1;
      while (j < len && keys[i + j] == run[j]) {
        j++;
      }
      if (j < len) continue;
      final at = i + from - start;
      if (best == null || (at - estimate).abs() < (best - estimate).abs()) {
        best = at;
      }
    }
    if (best != null) return best.clamp(0, fresh.length - 1);
  }
  return null;
}

/// Letters only: an old parse may glue note numbers or quotes to words.
String _key(BookTokens tokens, int i) =>
    tokens.textOf(i).replaceAll(_notLetter, '').toLowerCase();
