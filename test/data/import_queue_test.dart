import 'dart:io';

import 'package:book_app/book/import/book_importer.dart';
import 'package:book_app/data/import_queue.dart';
import 'package:book_app/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_importer.dart';

void main() {
  late Directory temp;
  late FakeImporter importer;
  late ProviderContainer container;
  late List<ImportQueueState> states;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('queue_');
    importer = FakeImporter();
    container = ProviderContainer(
      overrides: [bookImporterProvider.overrideWithValue(importer)],
    );
    states = [];
    container.listen(importQueueProvider, (_, next) => states.add(next));
  });
  tearDown(() {
    container.dispose();
    temp.deleteSync(recursive: true);
  });

  ImportQueue queue() => container.read(importQueueProvider.notifier);
  ImportQueueState state() => container.read(importQueueProvider);

  String file(String name) =>
      (File('${temp.path}/$name')..writeAsStringSync('x')).path;

  Future<void> idle() async {
    while (state().busy) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('imports files in order, one at a time, and deletes them', () async {
    final paths = [file('a.txt'), file('dup.txt'), file('bad.txt')];
    final results = await queue().add(paths);

    expect(importer.calls, ['a.txt', 'dup.txt', 'bad.txt']);
    expect(results.map((r) => r.runtimeType), [
      ImportAdded,
      ImportDuplicate,
      ImportFailed,
    ]);
    for (final path in paths) {
      expect(File(path).existsSync(), isFalse);
    }
    expect(state().busy, isFalse);
    expect(state().finished, hasLength(3));
    // Only the last state carries the batch results.
    expect(states.where((s) => s.finished != null), hasLength(1));
  });

  test('a failure does not stop the queue', () async {
    final results = await queue().add([file('bad1'), file('b'), file('bad2')]);

    expect(importer.calls, ['bad1', 'b', 'bad2']);
    expect(results.whereType<ImportAdded>(), hasLength(1));
    expect(results.whereType<ImportFailed>(), hasLength(2));
  });

  test('files added while it works go to the tail of the batch', () async {
    importer.hold = true;
    final first = queue().add([file('a'), file('b')]);
    await Future<void>.delayed(Duration.zero);
    expect(state().busy, isTrue);
    expect((state().total, state().done, state().current), (2, 0, 'a'));

    final second = queue().add([file('c')]);
    expect((state().total, state().done), (3, 0));
    for (var i = 0; i < 3; i++) {
      await importer.release();
    }

    expect((await first).map((r) => r.fileName), ['a', 'b']);
    expect((await second).map((r) => r.fileName), ['c']);
    expect(importer.calls, ['a', 'b', 'c']);
    // One batch: one summary of all three.
    expect(state().finished!.map((r) => r.fileName), ['a', 'b', 'c']);
  });

  test('the books of a box join the count', () async {
    await queue().add([file('a'), file('box.zip')]);
    await idle();

    expect(states.map((s) => s.total).toSet(), {2, 4});
    expect(state().done, 4);
    expect(state().finished, hasLength(4));
    // The count moves on inside the box too.
    expect(
      [
        for (final s in states)
          if (s.current?.startsWith('box.zip-') ?? false) s.done,
      ],
      [1, 2, 3],
    );
  });

  test('a new batch starts from zero and clears the old summary', () async {
    await queue().add([file('a'), file('b')]);
    states.clear();

    final results = await queue().add([file('c')]);

    expect(results, hasLength(1));
    expect(states.first.finished, isNull);
    expect((states.first.total, states.first.done), (1, 0));
    expect(state().finished, hasLength(1));
  });

  test('nothing to add, nothing happens', () async {
    expect(await queue().add([]), isEmpty);
    expect(states, isEmpty);
  });
}
