import 'package:book_app/speed/speed_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stored names; missing or unknown → word', () {
    expect(SpeedMode.parse('phrase'), SpeedMode.phrase);
    expect(SpeedMode.parse('guide'), SpeedMode.guide);
    expect(SpeedMode.parse(null), SpeedMode.word);
    expect(SpeedMode.parse('karaoke'), SpeedMode.word);
  });

  test('without Pro only the word mode is left', () {
    for (final mode in SpeedMode.values) {
      expect(mode.availableWith(pro: true), mode);
      expect(mode.availableWith(pro: false), SpeedMode.word);
    }
  });
}
