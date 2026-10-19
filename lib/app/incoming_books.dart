import 'dart:async';

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/data/import_queue.dart';
import 'package:book_app/features/reader/reader_screen.dart';
import 'package:book_app/platform/files_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Books that come from other apps ("Open with", "Share"; ADR 0005,
/// addendum 1) go to the import queue. One book → it opens at once over
/// the library, closing whatever was open (the place in the current book is
/// already kept); several → the library shows the summary, the screen stays.
class IncomingBooks extends ConsumerStatefulWidget {
  const IncomingBooks({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  final Widget child;

  @override
  ConsumerState<IncomingBooks> createState() => _IncomingBooksState();
}

class _IncomingBooksState extends ConsumerState<IncomingBooks> {
  StreamSubscription<List<String>>? _subscription;

  @override
  void initState() {
    super.initState();
    // Files the app was started with may wait in the stream already; the
    // queue can't change while the first screens build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _subscription = ref.read(incomingFilesProvider).listen(_receive);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _receive(List<String> paths) async {
    final results = await ref.read(importQueueProvider.notifier).add(paths);
    if (!mounted || paths.length != 1) return;
    // A box of several books counts as several files.
    final book = switch (results) {
      [ImportAdded(:final book)] || [ImportDuplicate(:final book)] => book,
      _ => null,
    };
    if (book == null) return;
    unawaited(
      widget.navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => ReaderScreen(bookId: book.id)),
        (route) => route.isFirst,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
