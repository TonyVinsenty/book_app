import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/data/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the import queue is doing (ADR 0005, addendum 1).
@immutable
final class ImportQueueState {
  const ImportQueueState({
    this.total = 0,
    this.done = 0,
    this.current,
    this.finished,
  });

  /// Books in this batch so far; a ZIP box counts each book inside.
  final int total;
  final int done;

  /// The book being imported now; null when the queue is idle.
  final String? current;

  /// The results of the last batch, once the queue has emptied; cleared
  /// when new files come.
  final List<ImportResult>? finished;

  bool get busy => current != null;
}

/// One queue for every way books come in: the picker, incoming files and
/// folders. Files are imported strictly one at a time (memory); ones
/// added while it works go to the tail. The queue owns the files given to
/// it and deletes each one when done.
class ImportQueue extends Notifier<ImportQueueState> {
  final _jobs = Queue<_Job>();
  var _results = <ImportResult>[];

  @override
  ImportQueueState build() => const ImportQueueState();

  /// Queues the files at [paths]; completes with their results, in order,
  /// when they are done.
  Future<List<ImportResult>> add(List<String> paths) => _add([
    for (final path in paths) _Job(fileNameOf(path), () async => path),
  ]);

  /// Queues one file that [fetch] makes (a copy the queue then owns) only
  /// when its turn comes, so a big folder never sits copied in full. With
  /// [touch] off a duplicate stays where it is in the library.
  Future<List<ImportResult>> addLater(
    String name,
    Future<String> Function() fetch, {
    bool touch = true,
  }) => _add([_Job(name, fetch, touch: touch)]);

  Future<List<ImportResult>> _add(List<_Job> jobs) async {
    if (jobs.isEmpty) return const [];
    _jobs.addAll(jobs);
    if (state.busy) {
      state = ImportQueueState(
        total: state.total + jobs.length,
        done: state.done,
        current: state.current,
      );
    } else {
      _results = [];
      state = ImportQueueState(total: jobs.length, current: jobs.first.name);
      unawaited(_run());
    }
    final done = await Future.wait([for (final job in jobs) job.done.future]);
    return [for (final results in done) ...results];
  }

  Future<void> _run() async {
    while (_jobs.isNotEmpty) {
      final job = _jobs.removeFirst();
      final doneBefore = state.done;
      var books = 0;
      List<ImportResult> results;
      File? file;
      try {
        file = File(await job.fetch());
        results = await ref
            .read(bookImporterProvider)
            .importFile(
              file,
              touch: job.touch,
              onBook: (name, count) {
                state = ImportQueueState(
                  // A box adds its other books to the count.
                  total: state.total + (books == 0 ? count - 1 : 0),
                  done: doneBefore + books,
                  current: name,
                );
                books++;
              },
            );
      } on Object {
        // The importer reports failures itself; this is a last resort, so
        // one bad file never stops the queue.
        results = [
          ImportFailed(
            job.name,
            file == null ? ImportError.unreadable : ImportError.damaged,
          ),
        ];
      }
      if (file != null) await _deleteQuietly(file);
      _results.addAll(results);
      job.done.complete(results);
      state = ImportQueueState(
        total: state.total,
        done: doneBefore + results.length,
        current: _jobs.isEmpty ? null : _jobs.first.name,
        finished: _jobs.isEmpty ? List.unmodifiable(_results) : null,
      );
    }
  }

}

final class _Job {
  _Job(this.name, this.fetch, {this.touch = true});

  final String name;

  /// The path of the file to import, which the queue deletes afterwards.
  final Future<String> Function() fetch;
  final bool touch;
  final done = Completer<List<ImportResult>>();
}

Future<void> _deleteQuietly(File file) async {
  try {
    if (file.existsSync()) await file.delete();
  } on FileSystemException {
    // A leftover in the cache folder; the next pick clears it.
  }
}

final importQueueProvider = NotifierProvider<ImportQueue, ImportQueueState>(
  ImportQueue.new,
);
