import 'dart:io';
import 'dart:math';

import 'package:book_app/app/theme/app_theme.dart';
import 'package:book_app/app/theme/page_texture.dart';
import 'package:book_app/book/model/book_content.dart';
import 'package:book_app/features/reader/page_images.dart';
import 'package:book_app/l10n/generated/app_localizations.dart';
import 'package:book_app/layout/page_style.dart';
import 'package:flutter/material.dart';

/// What footnotes are shown with (ADR 0008 п. 8): the book's notes, its
/// look on the page, the page side margins and the pictures folder.
@immutable
final class NoteBook {
  const NoteBook({
    required this.notes,
    required this.style,
    required this.side,
    required this.imagesDir,
  });

  final Map<String, Note> notes;
  final PageStyle style;
  final double side;
  final Directory imagesDir;

  /// The book font a little smaller.
  TextStyle get text => style.body.copyWith(fontSize: style.fontSize * 0.9);

  double get _gap => style.textScaler.scale(text.fontSize!) * 0.6;
}

/// Opens note [id]: a short one in a panel at the bottom, a long one as a
/// screen in the book's look (ADR 0008 п. 8); nothing if the book lacks it.
Future<void> openNote(BuildContext context, NoteBook book, String id) async {
  final note = book.notes[id];
  if (note == null) return;
  if (isShortNote(note, book, MediaQuery.sizeOf(context))) {
    final colors = context.readingColors;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colors.background,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      builder: (_) => NoteSheet(book: book, id: id),
    );
  } else {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteScreen(book: book, id: id),
      ),
    );
  }
}

/// A note is short when its text at the page width takes no more than half
/// of a [screen] (ADR 0008 п. 8).
bool isShortNote(Note note, NoteBook book, Size screen) =>
    noteHeight(note, book, screen.width - 2 * book.side) <= screen.height / 2;

/// Height of [note]'s text laid out [width] wide, as [NoteText] shows it.
double noteHeight(Note note, NoteBook book, double width) {
  width = max(width, 1);
  var height = 0.0;
  for (final block in note.blocks) {
    final double h;
    switch (block) {
      case TextBlock():
        final painter = TextPainter(
          text: _textOf(block, book, null),
          textDirection: TextDirection.ltr,
          textScaler: book.style.textScaler,
        )..layout(maxWidth: width);
        h = painter.height;
        painter.dispose();
      case ImageBlock(width: final w?, height: final h0?) when w > 0 && h0 > 0:
        h = h0 * min(1.0, width / w);
      case ImageBlock():
        continue;
      case SeparatorBlock():
        h = book.style.bodyLine;
    }
    height += h + book._gap;
  }
  return height;
}

/// The text of a note: its blocks one under another; a tap on a label of
/// another note calls [onNote].
class NoteText extends StatelessWidget {
  const NoteText({
    super.key,
    required this.note,
    required this.book,
    required this.onNote,
  });

  final Note note;
  final NoteBook book;
  final ValueChanged<String> onNote;

  @override
  Widget build(BuildContext context) {
    final night = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in note.blocks)
          if (_blockOf(block, night) case final child?)
            Padding(
              padding: EdgeInsets.only(bottom: book._gap),
              child: child,
            ),
      ],
    );
  }

  Widget? _blockOf(Block block, bool night) => switch (block) {
    TextBlock() => Text.rich(
      _textOf(block, book, onNote),
      textAlign: switch (block) {
        HeadingBlock() => TextAlign.center,
        ParagraphBlock(style: ParagraphStyle.normal || ParagraphStyle.note) =>
          book.style.align,
        ParagraphBlock() => TextAlign.left,
      },
      textScaler: book.style.textScaler,
    ),
    ImageBlock(:final assetId, width: final w?, height: final h?)
        when w > 0 && h > 0 =>
      Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: w.toDouble()),
          child: AspectRatio(
            aspectRatio: w / h,
            // Decoded no larger than shown, as on the page (ADR 0008 п. 6).
            child: LayoutBuilder(
              builder: (context, box) => Image(
                image: ResizeImage(
                  FileImage(File('${book.imagesDir.path}/$assetId')),
                  width: min(
                    w,
                    (box.maxWidth * MediaQuery.devicePixelRatioOf(context))
                        .ceil(),
                  ),
                ),
                fit: BoxFit.fill,
                color: night ? nightImageDim : null,
                colorBlendMode: night ? BlendMode.srcATop : null,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    ImageBlock() => null,
    SeparatorBlock() => Text(
      '* * *',
      textAlign: TextAlign.center,
      style: book.text,
      textScaler: book.style.textScaler,
    ),
  };
}

/// [block]'s text in the note font: italic and bold where its spans say,
/// labels of other notes small and raised; plain small text when
/// measuring ([onNote] null).
InlineSpan _textOf(
  TextBlock block,
  NoteBook book,
  ValueChanged<String>? onNote,
) {
  final base = block is HeadingBlock
      ? book.text.copyWith(fontWeight: FontWeight.w700)
      : book.text;
  final text = block.text;
  final cuts = {
    0,
    text.length,
    for (final s in block.spans) ...[
      min(s.start, text.length),
      min(s.end, text.length),
    ],
  }.toList()..sort();
  return TextSpan(
    style: base,
    children: [
      for (var i = 0; i + 1 < cuts.length; i++)
        if (cuts[i] < cuts[i + 1])
          _segmentOf(block, cuts[i], cuts[i + 1], book, base, onNote),
    ],
  );
}

InlineSpan _segmentOf(
  TextBlock block,
  int start,
  int end,
  NoteBook book,
  TextStyle base,
  ValueChanged<String>? onNote,
) {
  Span? marked(SpanKind kind) => block.spans
      .where((s) => s.kind == kind && s.start <= start && end <= s.end)
      .firstOrNull;
  final italic = marked(SpanKind.emphasis) != null;
  final bold = marked(SpanKind.strong) != null;
  final text = block.text.substring(start, end);
  final style = TextStyle(
    fontStyle: italic ? FontStyle.italic : null,
    fontWeight: bold ? FontWeight.w700 : null,
  );
  final label = marked(SpanKind.noteRef);
  if (label == null) return TextSpan(text: text, style: style);
  final active = book.notes.containsKey(label.noteId);
  final small = base.copyWith(
    fontSize: base.fontSize! * 0.62,
    color: active ? book.style.activeLabel : book.style.inactiveLabel,
  );
  if (onNote == null) return TextSpan(text: text, style: small);
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: active ? () => onNote(label.noteId!) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Transform.translate(
          offset: Offset(
            0,
            -book.style.textScaler.scale(base.fontSize!) * 0.38,
          ),
          child: Text(text, style: small, textScaler: book.style.textScaler),
        ),
      ),
    ),
  );
}

String _titleOf(Note note, AppLocalizations l10n) =>
    note.label == null ? l10n.noteTitleBare : l10n.noteTitle(note.label!);

/// A short note in a panel at the bottom: a note inside it opens in the
/// same panel with a back arrow, or as a screen if it is long.
class NoteSheet extends StatefulWidget {
  const NoteSheet({super.key, required this.book, required this.id});

  final NoteBook book;
  final String id;

  @override
  State<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<NoteSheet> {
  late final _shown = [widget.id];

  void _open(String id) {
    final note = widget.book.notes[id];
    if (note == null) return;
    if (isShortNote(note, widget.book, MediaQuery.sizeOf(context))) {
      setState(() => _shown.add(id));
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NoteScreen(book: widget.book, id: id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.readingColors;
    final l10n = AppLocalizations.of(context);
    final note = widget.book.notes[_shown.last]!;
    final nested = _shown.length > 1;
    return PopScope(
      canPop: !nested,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_shown.removeLast);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              nested ? 4 : widget.book.side,
              0,
              widget.book.side,
              8,
            ),
            child: Row(
              children: [
                if (nested)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onPressed: () => setState(_shown.removeLast),
                  ),
                Text(
                  _titleOf(note, l10n),
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              key: ValueKey(_shown.length),
              padding: EdgeInsets.fromLTRB(
                widget.book.side,
                0,
                widget.book.side,
                MediaQuery.viewPaddingOf(context).bottom + 16,
              ),
              child: NoteText(note: note, book: widget.book, onNote: _open),
            ),
          ),
        ],
      ),
    );
  }
}

/// A long note as a screen in the book's look, scrolled as one strip; a
/// note inside it opens as the next screen. The book stays where it was.
class NoteScreen extends StatelessWidget {
  const NoteScreen({super.key, required this.book, required this.id});

  final NoteBook book;
  final String id;

  @override
  Widget build(BuildContext context) {
    final colors = context.readingColors;
    final note = book.notes[id]!;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.text,
        scrolledUnderElevation: 0,
        title: Text(_titleOf(note, AppLocalizations.of(context))),
      ),
      body: TexturedPage(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(book.side, 8, book.side, 24),
            child: NoteText(
              note: note,
              book: book,
              onNote: (next) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => NoteScreen(book: book, id: next),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
