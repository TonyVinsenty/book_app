import 'package:book_app/speed/speed_mode.dart';
import 'package:book_app/stats/page_meter.dart';
import 'package:book_app/stats/play_meter.dart';
import 'package:book_app/stats/speed_histogram.dart';
import 'package:book_app/stats/stats_buffer.dart';
import 'package:book_app/stats/stats_records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime clock;
  late StatsBuffer buffer;

  DateTime now() => clock;
  void wait(int seconds) => clock = clock.add(Duration(seconds: seconds));

  setUp(() {
    clock = DateTime(2026, 10, 23, 20);
    buffer = StatsBuffer(now: now);
  });

  group('PageMeter', () {
    late PageMeter meter;

    setUp(() => meter = PageMeter(bookId: 7, buffer: buffer, now: now));

    ReadingDelta? only() {
      final reading = buffer.take().reading;
      return reading.isEmpty ? null : reading.single;
    }

    test('a page read at a normal pace gives time, words and speed', () {
      meter.open(250);
      wait(75);
      meter.open(240);

      final d = only()!;
      expect(
        (d.bookId, d.mode, d.day, d.dayPart),
        (7, ReadingMode.page, 20261023, 2),
      );
      expect((d.activeMs, d.words), (75000, 250));
      expect(d.pageSpeeds, {20: 1}); // 200 wpm
    });

    test('under 2 s is leafing: nothing counts', () {
      meter.open(250);
      wait(1);
      meter.open(250);
      wait(1);
      meter.close();

      expect(only(), isNull);
    });

    test('a short page gives time up to 60 s and words, no speed', () {
      meter.open(12);
      wait(90);
      meter.close();

      final d = only()!;
      expect((d.activeMs, d.words), (60000, 12));
      expect(d.pageSpeeds, isEmpty);
    });

    test('time over 3× the expected is cut and gives no speed', () {
      // 150 wpm before a median: 300 words take 2 min, the cut is 6 min.
      meter.open(300);
      wait(20 * 60);
      meter.close();

      final d = only()!;
      expect((d.activeMs, d.words), (360000, 300));
      expect(d.pageSpeeds, isEmpty);
    });

    test('the expected time follows the median; the cut stops at 10 min', () {
      meter
        ..medianWpm = 300
        ..open(300); // 1 min expected, cut at 3 min
      wait(200);
      meter.open(2000); // 400 s expected: 3× would be 20 min
      wait(30 * 60);
      meter.close();

      final d = only()!;
      expect(d.activeMs, 180000 + 600000);
      expect(d.pageSpeeds, isEmpty);
    });

    test('time stops while the page is covered', () {
      meter.open(250);
      wait(30);
      meter.visible = false; // panels, settings, RSVP, app hidden
      wait(600);
      meter.visible = true;
      wait(45);
      meter.close();

      final d = only()!;
      expect(d.activeMs, 75000);
      expect(d.pageSpeeds, {20: 1});
    });

    test('a page opened while covered starts counting when shown', () {
      meter
        ..visible = false
        ..open(250);
      wait(100);
      meter.visible = true;
      wait(75);
      meter.close();

      expect(only()!.activeMs, 75000);
    });

    test('pages go to the day and part of the day they end in', () {
      clock = DateTime(2026, 10, 23, 23, 59, 30);
      meter.open(250);
      wait(60);
      meter.close();

      final d = only()!;
      expect((d.day, d.dayPart), (20261024, 3));
    });
  });

  group('PlayMeter', () {
    late PlayMeter meter;

    setUp(
      () => meter = PlayMeter(
        bookId: 3,
        mode: SpeedMode.word,
        wpm: 350,
        wordIndex: 1000,
        buffer: buffer,
        now: now,
      ),
    );

    test('time while playing and the growth of the word index', () {
      meter.play();
      wait(30);
      meter.advance(1150);
      wait(30);
      meter.advance(1300);
      meter.stop();
      wait(100);
      meter.advance(1500); // not playing: no words

      final taken = buffer.take();
      final r = taken.reading.single;
      expect(
        (r.bookId, r.mode, r.activeMs, r.words),
        (3, ReadingMode.word, 60000, 300),
      );
      final p = taken.pace.single;
      expect(
        (p.wpm, p.words, p.activeMs, p.backs, p.pauses),
        (350, 300, 60000, 0, 0),
      );
    });

    test('a user pause counts only when reading goes on', () {
      meter.play();
      wait(10);
      meter.pause();
      wait(5);
      meter.play();
      wait(10);
      meter
        ..pause() // before the exit: no signal
        ..stop();

      final p = buffer.take().pace.single;
      expect((p.pauses, p.activeMs), (1, 20000));
    });

    test('back is a signal and neither takes off nor adds words', () {
      meter.play();
      wait(10);
      meter
        ..advance(1100)
        ..back(1050);
      wait(10);
      meter.advance(1120);
      meter.stop();

      final taken = buffer.take();
      expect(taken.reading.single.words, 170);
      expect(taken.pace.single.backs, 1);
    });

    test('a new pace and mode start their own rows', () {
      meter.play();
      wait(10);
      meter
        ..advance(1060)
        ..wpm = 400;
      wait(10);
      meter
        ..advance(1130)
        ..mode = SpeedMode.phrase;
      wait(10);
      meter
        ..advance(1200)
        ..stop();

      final taken = buffer.take();
      expect(
        {for (final p in taken.pace) (p.mode, p.wpm): p.words},
        {
          (SpeedMode.word, 350): 60,
          (SpeedMode.word, 400): 70,
          (SpeedMode.phrase, 400): 70,
        },
      );
      expect(
        {for (final r in taken.reading) r.mode: r.activeMs},
        {ReadingMode.word: 20000, ReadingMode.phrase: 10000},
      );
    });

    test('a jump forward that is not reading gives no words', () {
      meter.play();
      wait(5);
      meter
        ..seek(5000)
        ..advance(5010)
        ..stop();

      expect(buffer.take().reading.single.words, 0 + 10);
    });
  });

  group('StatsBuffer', () {
    test('is due every 30 s when there is something to write', () {
      expect(buffer.due, isFalse);
      buffer.addReading(
        const ReadingDelta(
          day: 1,
          bookId: 1,
          mode: ReadingMode.page,
          dayPart: 0,
          words: 1,
        ),
      );
      wait(29);
      expect(buffer.due, isFalse);
      wait(1);
      expect(buffer.due, isTrue);
      buffer.take();
      expect((buffer.isEmpty, buffer.due), (true, false));
    });

    test('merges deltas of one row', () {
      const a = ReadingDelta(
        day: 1,
        bookId: 1,
        mode: ReadingMode.page,
        dayPart: 0,
        activeMs: 10,
        words: 2,
        pageSpeeds: {20: 1},
      );
      buffer
        ..addReading(a)
        ..addReading(a);

      final r = buffer.take().reading.single;
      expect((r.activeMs, r.words), (20, 4));
      expect(r.pageSpeeds, {20: 2});
    });
  });

  group('median', () {
    test('the middle page, lower for an even count', () {
      expect(medianWpm({}), isNull);
      expect(medianWpm({20: 1}), 205);
      expect(medianWpm({30: 1, 10: 1, 20: 1}), 205);
      expect(medianWpm({10: 2, 20: 2}), 105);
      expect(medianWpm({25: 3, 10: 1, 40: 1}), 255);
      expect(pageCount({25: 3, 10: 1}), 4);
    });
  });
}
