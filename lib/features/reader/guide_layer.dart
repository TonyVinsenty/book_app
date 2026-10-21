import 'package:book_app/layout/chapter_layout.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

/// The leading highlight's soft mark under [word] on [page] (ADR 0004,
/// addendum for stage 10 п. 6). It goes under the page, which is drawn
/// over it in its own `RepaintBoundary`: at 1000 wpm only the mark is
/// painted again. A word carried over to the next line has two marks.
class GuideLayer extends StatelessWidget {
  const GuideLayer({
    super.key,
    required this.chapter,
    required this.page,
    required this.word,
    required this.color,
  });

  final ChapterLayout chapter;
  final int page;
  final ValueListenable<int> word;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: chapter.pageSize,
    painter: _GuidePainter(chapter, page, word, color),
  );
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.chapter, this.page, this.word, this.color)
    : super(repaint: word);

  final ChapterLayout chapter;
  final int page;
  final ValueListenable<int> word;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final box in chapter.wordBoxes(page, word.value)) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(box.inflate(2), const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.chapter != chapter ||
      old.page != page ||
      old.word != word ||
      old.color != color;
}
