import 'package:book_app/book/model/book_content.dart';

const _words = [
  'книга',
  'страница',
  'слово',
  'тихо',
  'и',
  'в',
  'на',
  'дорога',
  'ветер',
  'зима',
  'король',
  'меч',
  'рыцарь',
  'замок',
  'вечер',
  'река',
  'огонь',
  'не',
  'было',
  'сказал',
  'посмотрела',
  'неожиданно',
  'медленно',
  'солнце',
];

/// A generated book with every kind of block: headings, paragraphs of
/// different length, dialogue, a poem, an epigraph, a quote, a subtitle,
/// a separator, a picture, italic and bold text and a word longer than a
/// line. Same output for the same [seed].
BookContent sampleBook({int sections = 3, int paragraphs = 40, int seed = 1}) {
  var state = seed;
  int next(int max) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    return state % max;
  }

  String sentence(int words) {
    final text = [for (var i = 0; i < words; i++) _words[next(_words.length)]]
        .join(' ');
    return '${text[0].toUpperCase()}${text.substring(1)}.';
  }

  Section section(int s) {
    final blocks = <Block>[HeadingBlock(text: 'Глава ${s + 1}')];
    if (s == 0) {
      blocks.add(
        ParagraphBlock(text: sentence(12), style: ParagraphStyle.epigraph),
      );
    }
    for (var p = 0; p < paragraphs; p++) {
      switch (p % 13) {
        case 3:
          blocks.add(ParagraphBlock(text: '— ${sentence(4)} — ${sentence(6)}'));
        case 5:
          final text = sentence(30);
          blocks.add(
            ParagraphBlock(
              text: text,
              spans: [
                const Span(0, 10, SpanKind.emphasis),
                Span(5, 20, SpanKind.strong),
              ],
            ),
          );
        case 7:
          blocks.add(
            ParagraphBlock(
              text: [for (var i = 0; i < 4; i++) sentence(5)].join('\n'),
              style: ParagraphStyle.poem,
            ),
          );
        case 8:
          blocks.add(const SeparatorBlock());
        case 9:
          blocks.add(
            ParagraphBlock(text: 'Сверх${'длинное' * 12}слово ${sentence(3)}'),
          );
        case 10:
          blocks.add(
            ParagraphBlock(text: sentence(8), style: ParagraphStyle.subtitle),
          );
        case 11:
          blocks.add(const ImageBlock(assetId: 'pic'));
          blocks.add(
            ParagraphBlock(text: sentence(25), style: ParagraphStyle.quote),
          );
        default:
          blocks.add(ParagraphBlock(text: sentence(5 + next(120))));
      }
    }
    return Section(title: 'Глава ${s + 1}', blocks: blocks);
  }

  return BookContent(
    meta: const BookMeta(title: 'Пример', sourceFormat: SourceFormat.txt),
    sections: [for (var s = 0; s < sections; s++) section(s)],
  );
}
